.PHONY: agenix

agenix:
	EDITOR=nano sudo -E nix run github:ryantm/agenix -- \
  -i /home/leo/.config/age/keys.txt \
  -e $(SECRET)

deploy:
	nix run .#deploy-rs -- .#maelstrom
