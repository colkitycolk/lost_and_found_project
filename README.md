🚀 AI-Powered Lost & Found System

This project is an AI-driven platform that matches lost and found items using CLIP (Contrastive Language-Image Pre-training). It leverages a modern stack to handle real-time vector embeddings and similarity searching.

🏗️ System Architecture

Flutter App: The user interface for reporting items and viewing matches.

Supabase Backend: Local PostgreSQL database with pgvector for similarity search and pg_net for webhooks.

Edge Function (match-items): A Deno-based TypeScript middleware that coordinates between the database and the AI server.

Python AI Server: A FastAPI server running the CLIP model to generate 512-dimension vectors from text and images.

Docker: Orchestrates the entire Supabase ecosystem (Auth, API, Storage, Database).

1. Prerequisites & Environment

Before starting, ensure you have these installed:

Docker Desktop: Must be running to host the Supabase stack.

Python 3.9+: To run the local AI embedding server.

Supabase CLI: For local development and function serving.

Flutter SDK: For the mobile application.

2. Python AI Server Setup

This server handles the heavy lifting of generating CLIP embeddings.

Navigate to the directory: cd ai_server

Install dependencies:

pip install fastapi uvicorn sentence-transformers pillow python-multipart


Run the server:

python ai_server.py


The server will start on http://localhost:8000.

3. Supabase & Database Setup

We use the Supabase CLI to run the backend locally via Docker.

Start Supabase:

supabase start


Note: The first time you run this, it will download several Docker images.

Database Configuration:
Run this "Master Script" in your Supabase SQL Editor to establish the schema and AI triggers:

-- ENABLE EXTENSIONS
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- 1. CORE TABLES
CREATE TABLE public.profiles (
  id uuid REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
  full_name text,
  avatar_url text
);

CREATE TABLE public.items (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
  title text NOT NULL,
  description text,
  type text CHECK (type IN ('lost', 'found')),
  status text DEFAULT 'active',
  image_url text,
  text_embedding vector(512),
  image_embedding vector(512),
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE public.matches (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  lost_item_id uuid REFERENCES public.items(id) ON DELETE CASCADE,
  found_item_id uuid REFERENCES public.items(id) ON DELETE CASCADE,
  similarity_score float,
  created_at timestamp with time zone DEFAULT now()
);

-- 2. AI SIMILARITY LOGIC (RPC)
CREATE OR REPLACE FUNCTION find_matches(
  input_text_vec vector(512),
  input_img_vec vector(512),
  target_type text,
  threshold float DEFAULT 0.7
)
RETURNS TABLE (id uuid, final_score float) LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  SELECT items.id,
    CASE 
      WHEN input_img_vec IS NOT NULL AND items.image_embedding IS NOT NULL 
      THEN ((1 - (items.text_embedding <=> input_text_vec)) + (1 - (items.image_embedding <=> input_img_vec))) / 2
      ELSE (1 - (items.text_embedding <=> input_text_vec))
    END::float as final_score
  FROM items
  WHERE items.type = target_type 
    AND items.status = 'active'
    AND items.text_embedding IS NOT NULL
    AND (
      CASE 
        WHEN input_img_vec IS NOT NULL AND items.image_embedding IS NOT NULL 
        THEN ((1 - (items.text_embedding <=> input_text_vec)) + (1 - (items.image_embedding <=> input_img_vec))) / 2
        ELSE (1 - (items.text_embedding <=> input_text_vec))
      END > threshold
    )
  ORDER BY final_score DESC;
END; $$;

-- 3. THE AI TRIGGER (Automated Workflow)
-- This tells the database to notify our Edge Function whenever a new item is added.
CREATE OR REPLACE FUNCTION public.request_ai_embeddings()
RETURNS trigger AS $$
BEGIN
  PERFORM net.http_post(
    url := '[http://host.docker.internal:54321/functions/v1/match-items](http://host.docker.internal:54321/functions/v1/match-items)',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body := jsonb_build_object('record', row_to_json(NEW))
  );
  RETURN NEW;
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER tr_request_ai_embeddings
  AFTER INSERT ON public.items
  FOR EACH ROW EXECUTE FUNCTION public.request_ai_embeddings();


4. Edge Function Setup

The Edge Function is the "glue" between the database and the AI server.

Serve the function:

supabase functions serve match-items --no-verify-jwt


Networking: It uses host.docker.internal to reach the Python server running on your host machine.

5. Flutter App Setup

API Keys: Get your anon key by running supabase status.

Initialize:

await Supabase.initialize(
  url: '[http://127.0.0.1:54321](http://127.0.0.1:54321)', // Local Docker Gateway
  anonKey: 'YOUR_LOCAL_ANON_KEY',
);


💾 Maintenance & Data Persistence

To ensure your work is saved and shareable:

Stop and Backup: Use supabase stop (without flags) to keep your Docker volumes.

Export Schema: supabase db pull creates a migration file for the next developer.

Export Data: supabase db dump --data-only > supabase/seed.sql saves your current items/users.