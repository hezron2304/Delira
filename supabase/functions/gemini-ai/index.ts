import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { GoogleGenerativeAI } from "npm:@google/generative-ai@0.2.1"

const apiKey = Deno.env.get("GEMINI_API_KEY")!
const genAI = new GoogleGenerativeAI(apiKey)

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req: any) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const requestBody = await req.json()
    const { type, text, imageBase64 } = requestBody

    if (type === 'chat') {
      // Basic text generation
      const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" })
      const result = await model.generateContent(text)
      const responseText = result.response.text()
      
      return new Response(JSON.stringify({ text: responseText }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      })
    } 
    else if (type === 'vision') {
      // Vision model with image
      const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" })
      
      const imagePart = {
        inlineData: {
          data: imageBase64,
          mimeType: "image/jpeg"
        }
      }

      const result = await model.generateContent([text, imagePart])
      const responseText = result.response.text()

      return new Response(JSON.stringify({ text: responseText }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      })
    }

    return new Response(JSON.stringify({ error: "Tipe request tidak valid. Gunakan 'chat' atau 'vision'." }), { 
      status: 400, 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
    })

  } catch (error: any) {
    console.error("Error in gemini-ai function:", error)
    return new Response(JSON.stringify({ error: error.message || "Internal server error" }), { 
      status: 500, 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
    })
  }
})
