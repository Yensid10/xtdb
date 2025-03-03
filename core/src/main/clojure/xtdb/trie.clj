(ns xtdb.trie
  (:require [clojure.string :as str]
            [xtdb.buffer-pool]
            [xtdb.types :as types]
            [xtdb.util :as util]
            [xtdb.vector.writer :as vw])
  (:import com.carrotsearch.hppc.ByteArrayList
           (java.lang AutoCloseable)
           (java.nio.file Path)
           java.time.LocalDate
           (java.util ArrayList Arrays List)
           (org.apache.arrow.memory ArrowBuf BufferAllocator)
           (org.apache.arrow.vector VectorSchemaRoot)
           (org.apache.arrow.vector.types.pojo ArrowType$Union Field Schema)
           org.apache.arrow.vector.types.UnionMode
           (xtdb.arrow Relation)
           xtdb.BufferPool
           (xtdb.trie ArrowHashTrie$Leaf HashTrie$Node ISegment MemoryHashTrie MemoryHashTrie$Leaf MergePlanNode Trie Trie$Key TrieWriter)
           (xtdb.util TemporalBounds TemporalDimension)))

(defn ->trie-key [^long level, ^LocalDate recency, ^bytes part, ^long block-idx]
  (str (Trie$Key. level recency (some-> part ByteArrayList/from) block-idx)))

(defn ->l0-trie-key [^long block-idx]
  (->trie-key 0 nil nil block-idx))

(defn ->l1-trie-key [^LocalDate recency, ^long block-idx]
  (->trie-key 1 recency nil block-idx))

(defn parse-trie-key [trie-key]
  (try
    (let [k (Trie/parseKey trie-key)]
      {:trie-key trie-key
       :level (.getLevel k)
       :recency (.getRecency k)
       :part (some-> (.getPart k) (.toArray))
       :block-idx (.getBlockIndex k)})
    (catch IllegalArgumentException _)
    (catch IllegalStateException _)))

(defn parse-trie-file-path [^Path file-path]
  (-> (parse-trie-key (str (.getFileName file-path)))
      (assoc :file-path file-path)))

(def ^java.nio.file.Path tables-dir (util/->path "tables"))

(defn table-name->table-path ^java.nio.file.Path [^String table-name]
  (.resolve tables-dir (-> table-name (str/replace #"[\.\/]" "\\$"))))

(defn table-dir->table-name ^String [^String table-dir]
  (str/replace-first table-dir #"\$" "/" ))

(defn ->table-data-file-path ^java.nio.file.Path [table-name trie-key]
  (-> (table-name->table-path table-name)
      (.resolve (format "data/%s.arrow" trie-key))))

(defn ->table-meta-dir ^java.nio.file.Path [table-name]
  (-> (table-name->table-path table-name)
      (.resolve "meta")))

(defn ->table-meta-file-path [table-name trie-key]
  (-> (->table-meta-dir table-name)
      (.resolve (format "%s.arrow" trie-key))))

(defn data-rel-schema ^org.apache.arrow.vector.types.pojo.Schema [^Field put-doc-field]
  (Schema. [(types/col-type->field "_iid" [:fixed-size-binary 16])
            (types/col-type->field "_system_from" types/temporal-col-type)
            (types/col-type->field "_valid_from" types/temporal-col-type)
            (types/col-type->field "_valid_to" types/temporal-col-type)
            (types/->field "op" (ArrowType$Union. UnionMode/Dense (int-array (range 3))) false
                           put-doc-field
                           (types/col-type->field "delete" :null)
                           (types/col-type->field "erase" :null))]))

(defn open-log-data-wtr
  (^xtdb.vector.IRelationWriter [^BufferAllocator allocator]
   (open-log-data-wtr allocator (data-rel-schema (types/col-type->field "put" [:struct {}]))))

  (^xtdb.vector.IRelationWriter [^BufferAllocator allocator data-schema]
   (util/with-close-on-catch [root (VectorSchemaRoot/create data-schema allocator)]
     (vw/root->writer root))))

(defn write-live-trie-node [^TrieWriter trie-wtr, ^HashTrie$Node node, ^Relation data-rel]
  (let [copier (.rowCopier (.getDataRel trie-wtr) data-rel)]
    (letfn [(write-node! [^HashTrie$Node node]
              (if-let [children (.getIidChildren node)]
                (let [child-count (alength children)
                      !idxs (int-array child-count)]
                  (dotimes [n child-count]
                    (aset !idxs n
                          (unchecked-int
                           (if-let [child (aget children n)]
                             (write-node! child)
                             -1))))

                  (.writeIidBranch trie-wtr !idxs))

                (let [^MemoryHashTrie$Leaf leaf node]
                  (-> (Arrays/stream (.getData leaf))
                      (.forEach (fn [idx]
                                  (.copyRow copier idx))))

                  (.writeLeaf trie-wtr))))]

      (write-node! node))))

(defn write-live-trie! [^BufferAllocator allocator, ^BufferPool buffer-pool,
                        table-name, trie-key,
                        ^MemoryHashTrie trie, ^Relation data-rel]
  (util/with-open [trie-wtr (TrieWriter. allocator buffer-pool (.getSchema data-rel) table-name trie-key
                                         false)]
    (let [trie (.compactLogs trie)]
      (write-live-trie-node trie-wtr (.getRootNode trie) data-rel)

      (.end trie-wtr))))

(defrecord Segment [trie]
  ISegment
  (getTrie [_] trie))

(defprotocol MergePlanPage
  (load-page [mpg ^BufferPool buffer-pool vsr-cache])
  (test-metadata [msg])
  (temporal-bounds [msg]))

(defn ->live-trie ^MemoryHashTrie [log-limit page-limit iid-rdr]
  (-> (doto (MemoryHashTrie/builder iid-rdr)
        (.setLogLimit log-limit)
        (.setPageLimit page-limit))
      (.build)))

(defn max-valid-to ^long [^TemporalBounds tb]
  (.getUpper (.getValidTime tb)))

(defn min-valid-from ^long [^TemporalBounds tb]
  (.getLower (.getValidTime tb)))

(defn min-system-from ^long [^TemporalBounds tb]
  (.getLower (.getSystemTime tb)))

(defn max-system-from ^long [^TemporalBounds tb]
  (.getMaxSystemFrom tb))

(defn ->merge-task
  ([mp-pages] (->merge-task mp-pages (TemporalBounds.)))
  ([mp-pages ^TemporalBounds query-bounds]
   (let [leaves (ArrayList.)]
     (loop [[mp-page & more-mp-pages] mp-pages
            node-taken? false
            smallest-valid-from Long/MAX_VALUE
            largest-valid-to Long/MIN_VALUE
            smallest-system-from Long/MAX_VALUE
            non-taken-pages []]
       (if mp-page
         (let [^TemporalBounds page-bounds (temporal-bounds mp-page)
               take-node? (and (.intersects page-bounds query-bounds)
                               (test-metadata mp-page))]

           (if take-node?
             (do
               (.add leaves mp-page)
               (recur more-mp-pages
                      true
                      (min smallest-valid-from (min-valid-from page-bounds))
                      (max largest-valid-to (max-valid-to page-bounds))
                      (min smallest-system-from (min-system-from page-bounds))
                      non-taken-pages))

             (recur more-mp-pages
                    node-taken?
                    smallest-valid-from
                    largest-valid-to
                    smallest-system-from
                    (cond-> non-taken-pages
                      (.intersects (.getSystemTime page-bounds) (.getSystemTime query-bounds))
                      (conj mp-page)))))

         (when node-taken?
           (let [valid-time (TemporalDimension. smallest-valid-from largest-valid-to)]
             (loop [[page & more-pages] non-taken-pages]
               (when page
                 (let [page-valid-time (.getValidTime ^TemporalBounds (temporal-bounds page))
                       page-largest-system-from (max-system-from (temporal-bounds page))]
                   (when (and (<= smallest-system-from page-largest-system-from)
                              (.intersects valid-time page-valid-time))
                     (.add leaves page))
                   (recur more-pages)))))
           (vec leaves)))))))

(definterface IDataRel
  (^org.apache.arrow.vector.types.pojo.Schema getSchema [])
  (^xtdb.arrow.RelationReader loadPage [trie-leaf]))

(deftype ArrowDataRel [^BufferAllocator allocator
                       ^BufferPool buffer-pool
                       ^Path data-file
                       ^Schema schema
                       ^List rels-to-close]
  IDataRel
  (getSchema [_] schema)

  (loadPage [_ trie-leaf]
    (util/with-open [rb (.getRecordBatch buffer-pool data-file (.getDataPageIndex ^ArrowHashTrie$Leaf trie-leaf))]
      (let [rel (Relation/fromRecordBatch allocator schema rb)]
        (.add rels-to-close rel)
        rel)))

  AutoCloseable
  (close [_]
    (util/close rels-to-close)))

(defn open-data-rels [^BufferAllocator allocator, ^BufferPool buffer-pool, table-name, trie-keys]
  (util/with-close-on-catch [data-rels (ArrayList.)]
    (doseq [trie-key trie-keys]
      (let [data-file (->table-data-file-path table-name trie-key)
            footer (.getFooter buffer-pool data-file)]
        (.add data-rels (ArrowDataRel. allocator buffer-pool data-file (.getSchema footer) (ArrayList.)))))
    (vec data-rels)))

(defn load-data-page [^MergePlanNode merge-plan-node]
  (let [{:keys [^IDataRel data-rel]} (.getSegment merge-plan-node)
        trie-leaf (.getNode merge-plan-node)]
    (.loadPage data-rel trie-leaf)))
