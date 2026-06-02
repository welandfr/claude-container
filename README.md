# claude-container

Run Claude Code isolated in a container. It will only have access to the current working directory.

## Method 1: Build image once, then use docker-command (alias)

```sh
# In the same folder as the Dockerfile:
docker build -t claude-code:latest .
```
Create this alias in `.bashrc` or `.zshrc` or similar (modify or add ports as needed): 
```sh
alias claude-code='docker run --rm -it \
	-v "$PWD:/workspace" \
	-v claude-home:/home/node \
	-p 3000:3000 -p 8000:8000 \
	-w /workspace claude-code:latest'

```

## Method 2: Use the compose file
Start: `docker compose run --rm claude`
