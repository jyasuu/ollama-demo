#!/bin/bash

# Ollama API endpoint
OLLAMA_API="http://localhost:11434/api/embeddings"
GENERATE_API="http://localhost:11434/api/generate"

# Database connection parameters
DB_NAME="mydb"
DB_USER="myuser"
DB_PASSWORD="mypassword"
DB_HOST="localhost"
DB_PORT="5444"

curl -X POST http://localhost:11434/api/pull \
    -H "Content-Type: application/json" \
    -d '{"model": "all-minilm"}'

curl -X POST http://localhost:11434/api/pull \
    -H "Content-Type: application/json" \
    -d '{"model": "llama3.2"}'

# Function to get embedding from Ollama API
get_embedding() {
    local text="$1"
    response=$(curl -s -X POST "$OLLAMA_API" -H "Content-Type: application/json" -d "{\"model\": \"all-minilm\", \"prompt\": \"$text\"}")
    echo "$response" | jq -r '.embedding'
}

# Function to insert documents into PostgreSQL
insert_documents() {
    documents=("Seoul Tower|Seoul Tower is a communication and observation tower located on Namsan Mountain in central Seoul, South Korea."
               "Gwanghwamun Gate|Gwanghwamun is the main and largest gate of Gyeongbokgung Palace, in Jongno-gu, Seoul, South Korea."
               "Bukchon Hanok Village|Bukchon Hanok Village is a Korean traditional village in Seoul with a long history."
               "Myeong-dong Shopping Street|Myeong-dong is one of the primary shopping districts in Seoul, South Korea."
               "Dongdaemun Design Plaza|The Dongdaemun Design Plaza is a major urban development landmark in Seoul, South Korea.")

    for doc in "${documents[@]}"; do
        title=$(echo "$doc" | cut -d'|' -f1)
        content=$(echo "$doc" | cut -d'|' -f2)
        embedding=$(get_embedding "$content")
        embedding_array="[$(echo "$embedding" | sed 's/,/ /g')]"
        
        # Insert into PostgreSQL using psql
        PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -p $DB_PORT -c \
        "CREATE EXTENSION vector;
        CREATE TABLE IF NOT EXISTS documents (
            id SERIAL PRIMARY KEY,
            title TEXT,
            content TEXT,
            embedding VECTOR(384)
        );
        INSERT INTO documents (title, content, embedding) VALUES ('$title', '$content', '$embedding_array');"
    done
}

# Function to generate response using Ollama API
generate_response() {
    local prompt="$1"
    response=$(curl -s -X POST "$GENERATE_API" -H "Content-Type: application/json" \
                -d "{\"model\": \"llama3.2\", \"prompt\": \"$prompt\", \"stream\": false}")
    echo "$response" | jq -r '.response'
}

# Function to retrieve and generate response based on a query
retrieve_and_generate_response() {
    local query="$1"
    
    # Get embedding for the query
    query_embedding=$(get_embedding "$query")
    embedding_string="[$(echo "$query_embedding" | sed 's/,/ /g')]"
    
    # Retrieve relevant documents using cosine similarity in PostgreSQL
    result=$(PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -p $DB_PORT -At -c \
    "CREATE EXTENSION vector;
    CREATE TABLE IF NOT EXISTS documents (
            id SERIAL PRIMARY KEY,
            title TEXT,
            content TEXT,
            embedding VECTOR(384)
        );
        SELECT title, content FROM documents ORDER BY embedding <=> '$embedding_string'::vector LIMIT 5;")
    
    context=""
    while IFS="|" read -r title content; do
        context="$context\nTitle: $title\nContent: $content"
    done <<< "$result"
    
    # Generate response based on the context
    prompt="Query: $query\nContext: $context\nPlease provide a concise answer based on the given context."
    response=$(generate_response "$prompt")
    
    echo "Response: $response"
}

# Main function to execute the workflow
main() {
    retrieve_and_generate_response "Tell me about landmarks in Seoul"
}

# Run the main function
main
