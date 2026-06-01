# claude-container

## Method 1: Build image once, then use docker-command (alias)

```sh
# In the same folder as the Dockerfile:
docker build -t claude-code:latest .
```
Create this alias in `.bashrc` or `.zshrc` or similar: 
```sh
alias claude-code='docker run --rm -it -v "$PWD:/workspace" -w /workspace claude-code:latest'
```

## Method 2: Use the compose file
Start: `docker compose run --rm claude`
