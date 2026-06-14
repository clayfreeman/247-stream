PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin

ETC_DIR ?= /etc/247-stream
DEFAULTS_DIR ?= /etc/default
SYSTEMD_DIR ?= /etc/systemd/system

CONSUMER_TARGET = stream-consumer
CONSUMER_SRC = ./stream-consumer

CONSUMER_DEFAULTS_SRC = ./stream-consumer.defaults
CONSUMER_DEFAULTS_DEST = $(DEFAULTS_DIR)/stream-consumer

CONSUMER_SERVICE_SRC = ./stream-consumer@.service
CONSUMER_SERVICE_DEST = $(SYSTEMD_DIR)/stream-consumer@.service

PRODUCER_TARGET = stream-producer
PRODUCER_SRC = ./stream-producer

PRODUCER_DEFAULTS_SRC = ./stream-producer.defaults
PRODUCER_DEFAULTS_DEST = $(DEFAULTS_DIR)/stream-producer

PRODUCER_SERVICE_SRC = ./stream-producer@.service
PRODUCER_SERVICE_DEST = $(SYSTEMD_DIR)/stream-producer@.service

.PHONY: install uninstall reload

install:
	groupadd 247-stream || true
	useradd -r -m -d /var/lib/247-stream -s /usr/sbin/nologin -g 247-stream 247-stream || true

	install -d -o root -g 247-stream -m 755 $(ETC_DIR)

	install -d $(ETC_DIR)/hooks.d
	install -m 755 ./hooks.d/.functions.sh $(ETC_DIR)/hooks.d/.functions.sh

	[ -e $(ETC_DIR)/hooks.d/00-pin-chat-message.sh ] || install -m 644 ./hooks.d/00-pin-chat-message.sh $(ETC_DIR)/hooks.d/00-pin-chat-message.sh

	install -d -o 247-stream -g 247-stream -m 2754 $(ETC_DIR)/keys

	install -d -o 247-stream -g 247-stream -m 755 /var/lib/247-stream
	install -d -o 247-stream -g 247-stream -m 755 /var/lib/247-stream/.config
	install -d -o 247-stream -g 247-stream -m 755 /var/lib/247-stream/.config/twitch
	install -d -o 247-stream -g 247-stream -m 2754 /var/lib/247-stream/.config/twitch/auth

	[ -e /var/lib/247-stream/.config/twitch/client ] || install -m 640 -o 247-stream -g 247-stream /dev/null /var/lib/247-stream/.config/twitch/client

	install -d $(BINDIR)
	install -m 755 $(CONSUMER_SRC) $(BINDIR)/$(CONSUMER_TARGET)
	install -m 755 $(PRODUCER_SRC) $(BINDIR)/$(PRODUCER_TARGET)

	install -d $(DEFAULTS_DIR)
	[ -e $(CONSUMER_DEFAULTS_DEST) ] || install -m 644 $(CONSUMER_DEFAULTS_SRC) $(CONSUMER_DEFAULTS_DEST)
	[ -e $(PRODUCER_DEFAULTS_DEST) ] || install -m 644 $(PRODUCER_DEFAULTS_SRC) $(PRODUCER_DEFAULTS_DEST)

	install -d $(SYSTEMD_DIR)
	install -m 644 $(CONSUMER_SERVICE_SRC) $(CONSUMER_SERVICE_DEST)
	install -m 644 $(PRODUCER_SERVICE_SRC) $(PRODUCER_SERVICE_DEST)

	@$(MAKE) reload

reload:
	systemctl daemon-reload

uninstall:
	systemctl list-units 'stream-consumer@*.service' --all --no-legend | awk '{print $$1}' | xargs -r systemctl disable --now
	systemctl list-units 'stream-producer@*.service' --all --no-legend | awk '{print $$1}' | xargs -r systemctl disable --now

	userdel 247-stream || true
	groupdel 247-stream || true

	rm -f $(BINDIR)/$(CONSUMER_TARGET)
	rm -f $(BINDIR)/$(PRODUCER_TARGET)
	rm -f $(CONSUMER_SERVICE_DEST)
	rm -f $(PRODUCER_SERVICE_DEST)

	@$(MAKE) reload
