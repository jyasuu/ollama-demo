# ollama-demo

[ollama](https://ollama.com/)

## install

```sh
curl -fsSL https://ollama.com/install.sh | sh

```

## embedding-models

[embedding-models](https://ollama.com/blog/embedding-models)

```sh
ollama serve
ollama pull mxbai-embed-large

curl http://localhost:11434/api/embeddings -d '{
  "model": "mxbai-embed-large",
  "prompt": "Llamas are members of the camelid family"
}' | jq

pip install ollama chromadb
python3 example.py
```