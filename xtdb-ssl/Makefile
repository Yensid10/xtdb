.PHONY: all clean build run

# Build Docker image
build:
	docker build -t xtdb-ssl .

# Run the container
run:
	docker run -it --rm \
		--name xtdb-ssl \
		-p 5432:5432 \
		-p 8081:8080 \
		-p 3001:3000 \
		xtdb-ssl

all: build run

connect:
	psql "host=localhost port=5432 dbname=xtdb user=xtdb sslmode=require"

# Clean up
clean:
	docker rm -f xtdb-ssl 2>/dev/null || true
	docker rmi xtdb-ssl 2>/dev/null || true


# docker run -it --rm \       
# 	-p 5432:5432 \
# 	-p 8081:8080 \
# 	-p 3001:3000 \
# 	-v $(pwd)/xtdb.jks:/ssl/	xtdb.jks:ro \
# 	-v $(pwd)/ssl_config.yam	l:/config.yaml:ro \
# 	ghcr.io/xtdb/xtdb:2.0.0-	beta6 \
# 	-f /config.yaml