DATA_PATH   = /home/ayel-arr/data
COMPOSE     = docker compose -f srcs/docker-compose.yml

all: setup
	$(COMPOSE) up --build -d

setup:
	@mkdir -p $(DATA_PATH)/mariadb
	@mkdir -p $(DATA_PATH)/wordpress

down:
	$(COMPOSE) down

clean: down
	docker system prune -af

fclean: clean
	@rm -rf $(DATA_PATH)/mariadb
	@rm -rf $(DATA_PATH)/wordpress
	docker volume prune -f

re: fclean all

.PHONY: all setup down clean fclean re
