# pgai

[pgai](https://github.com/timescale/pgai)


```sh
curl -O https://raw.githubusercontent.com/timescale/pgai/main/examples/docker_compose_pgai_ollama/docker-compose.yml


docker compose exec ollama ollama pull all-minilm
docker compose exec ollama ollama pull tinyllama

docker compose exec -it db psql
```

```sql

CREATE EXTENSION IF NOT EXISTS ai CASCADE;

CREATE TABLE wiki (
    id      TEXT PRIMARY KEY,
    url     TEXT,
    title   TEXT,
    text    TEXT
);

SELECT ai.load_dataset('wikimedia/wikipedia', '20231101.en', table_name=>'wiki', batch_size=>5, max_batches=>1, if_table_exists=>'append');

SELECT ai.create_vectorizer(
     'wiki'::regclass,
     destination => 'wiki_embeddings',
     embedding => ai.embedding_ollama('all-minilm', 384),
     chunking => ai.chunking_recursive_character_text_splitter('text')
);

select * from ai.vectorizer_status;

SELECT title, chunk
FROM wiki_embeddings 
ORDER BY embedding <=> ai.ollama_embed('all-minilm', 'properties of light')
LIMIT 1;
INSERT INTO wiki (id, url, title, text) VALUES (11,'https://en.wikipedia.org/wiki/Pgai', 'pgai - Power your AI applications with PostgreSQL', 'pgai is a tool to make developing RAG and other AI applications easier. It makes it simple to give an LLM access to data in your PostgreSQL database by enabling semantic search on your data and using the results as part of the Retrieval Augmented Generation (RAG) pipeline. This allows the LLM to answer questions about your data without needing to being trained on your data.');
SELECT title, chunk
FROM wiki_embeddings 
ORDER BY embedding <=> ai.ollama_embed('all-minilm', 'AI tools')
LIMIT 1;

SELECT answer->>'response' as summary
FROM ai.ollama_generate('tinyllama', 
'Summarize the following and output the summary in a single sentence: '|| (SELECT text FROM wiki WHERE title like 'pgai%')) as answer;
```