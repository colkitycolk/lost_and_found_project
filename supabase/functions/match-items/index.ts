import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req: Request) => {
  console.log("--- New Request Started ---");

  try {
    const { record } = await req.json();
    console.log("Checkpoint 1: Record received ->", record.title);
    
    // Log the URL to make sure it's actually coming through
    console.log("Image URL from record:", record.image_url);

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    const PYTHON_SERVER = "http://host.docker.internal:8000";

    // --- TEXT EMBEDDING ---
    console.log("Checkpoint 2: Requesting Text Embedding...");
    const textRes = await fetch(`${PYTHON_SERVER}/embed`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ text: `${record.title}. ${record.description}` })
    });
    
    if (!textRes.ok) throw new Error(`Python Text API failed: ${textRes.statusText}`);
    const { embedding: textVec } = await textRes.json();
    console.log("Checkpoint 3: Text Embedding received.");

    // --- IMAGE EMBEDDING (Updated for image_url) ---
    let imageVec = null;
    if (record.image_url) {
      console.log("Checkpoint 4: Image URL found, fetching image data...");
      
      try {
        // Fetch the image from the public URL
        const imageResponse = await fetch(record.image_url);
        if (!imageResponse.ok) throw new Error("Failed to fetch image from URL");
        
        const blob = await imageResponse.blob();
        console.log("Checkpoint 5: Image blob created, sending to Python...");

        const formData = new FormData();
        // 'file' must match the parameter name in your Python FastAPI code
        formData.append('file', blob, 'image.jpg');

        const imgRes = await fetch(`${PYTHON_SERVER}/embed-image`, {
          method: "POST",
          body: formData
        });

        if (!imgRes.ok) {
          const errorDetail = await imgRes.text();
          throw new Error(`Python Image API failed: ${errorDetail}`);
        }

        const imgJson = await imgRes.json();
        imageVec = imgJson.embedding;
        console.log("Checkpoint 6: Image Embedding received.");
      } catch (imgErr) {
        console.error("Image Processing Error:", imgErr.message);
        // We continue even if image fails so we still have text matching
      }
    }

    // --- UPDATE DATABASE ---
    console.log("Checkpoint 7: Updating Database with vectors...");
    const { error: updError } = await supabase.from('items').update({ 
      text_embedding: textVec, 
      image_embedding: imageVec 
    }).eq('id', record.id);

    if (updError) throw updError;

    // --- MATCHING ---
    console.log("Checkpoint 8: Searching for matches...");
    const targetType = record.type === 'lost' ? 'found' : 'lost';
    
    const { data: matches, error: rpcError } = await supabase.rpc('find_matches', {
      input_text_vec: textVec,
      input_img_vec: imageVec,
      target_type: targetType,
      threshold: 0.7
    });

    if (rpcError) throw rpcError;

    if (matches && matches.length > 0) {
      console.log(`Checkpoint 9: Found ${matches.length} matches! Inserting...`);
      for (const m of matches) {
        await supabase.from('matches').insert({
          lost_item_id: record.type === 'lost' ? record.id : m.id,
          found_item_id: record.type === 'found' ? record.id : m.id,
          similarity_score: m.final_score
        });
      }
    }

    console.log("--- Request Finished Successfully ---");
    return new Response(JSON.stringify({ success: true }), { headers: { "Content-Type": "application/json" } });

  } catch (err) {
    console.error("CRITICAL ERROR:", err.message);
    return new Response(JSON.stringify({ error: err.message }), { status: 500 });
  }
})