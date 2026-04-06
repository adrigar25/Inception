COMPOSE := cd srcs && docker compose
LOGIN := $(shell whoami)
DATA_DIR := /home/$(LOGIN)/data

.PHONY: all up down start stop logs ps clean fclean re

all: up

up:
	mkdir -p $(DATA_DIR)/wp_data $(DATA_DIR)/db_data
	$(COMPOSE) up --build -d

down:
	$(COMPOSE) down

start:
	$(COMPOSE) start

stop:
	$(COMPOSE) stop

logs:
	$(COMPOSE) logs --tail=100

ps:
	$(COMPOSE) ps

clean:
	$(COMPOSE) down -v --remove-orphans

fclean: clean
	docker run --rm -v $(DATA_DIR):/data debian:bullseye sh -c "rm -rf /data/wp_data /data/db_data"

re: fclean up
