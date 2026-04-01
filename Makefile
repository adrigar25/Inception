COMPOSE := cd srcs && docker compose
DATA_DIR := /home/agarcia/data

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
	rm -rf $(DATA_DIR)/wp_data $(DATA_DIR)/db_data

re: fclean up
