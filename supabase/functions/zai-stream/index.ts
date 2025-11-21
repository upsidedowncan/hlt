import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req) => {
  const ZAI_API_KEY = Deno.env.get("ZAI_API_KEY")
  if (!ZAI_API_KEY) {
    return new Response("Missing API key", { status: 500 })
  }

  const body = await req.json()
  const isStreaming = body.stream === true

  const zaiRequest = {
    model: body.model || "glm-4.5-flash",
    messages: [
      { role: "system", content: body.systemPrompt || "You are a helpful AI assistant." },
      { role: "user", content: body.message }
    ],
    max_tokens: body.maxTokens || 500,
    temperature: body.temperature || 0.7,
    stream: isStreaming
  }

  const response = await fetch("https://api.z.ai/api/paas/v4/chat/completions", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${ZAI_API_KEY}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify(zaiRequest)
  })

  // ---- NON-STREAMING ----
  if (!isStreaming) {
    const data = await response.json()
    let content = data?.choices?.[0]?.message?.content ?? "No response"
    let reasoning = data?.choices?.[0]?.message?.reasoning_content ?? null

    return new Response(
      JSON.stringify({ content, reasoning, usage: data.usage }),
      { headers: { "Content-Type": "application/json" } }
    )
  }

  // ---- STREAMING (SSE) ----
  const reader = response.body!.getReader()
  const encoder = new TextEncoder()
  const decoder = new TextDecoder()

  return new Response(
    new ReadableStream({
      async start(controller) {
        while (true) {
          const { done, value } = await reader.read()
          if (done) break

          const text = decoder.decode(value)
          const lines = text.split("\n")

          for (const line of lines) {
            if (!line.startsWith("data: ")) continue
            const jsonStr = line.slice(6)
            if (jsonStr === "[DONE]") {
              controller.enqueue(encoder.encode("data: [DONE]\n\n"))
              controller.close()
              return
            }

            try {
              const json = JSON.parse(jsonStr);
              const delta = json?.choices?.[0]?.delta;

              if (!delta) continue;

              // STREAM CONTENT TOKENS
              if (delta.content) {
                controller.enqueue(
                  encoder.encode(
                    `data: ${JSON.stringify({
                      type: "content",
                      token: delta.content,
                    })}\n\n`
                  )
                );
              }

              // STREAM REASONING TOKENS
              if (delta.reasoning_content) {
                controller.enqueue(
                  encoder.encode(
                    `data: ${JSON.stringify({
                      type: "reasoning",
                      token: delta.reasoning_content,
                    })}\n\n`
                  )
                );
              }

            } catch (err) {
              // skip malformed chunks
            }
          }
        }

        controller.enqueue(encoder.encode("data: [DONE]\n\n"))
        controller.close()
      }
    }),
    {
      headers: {
        "Content-Type": "text/event-stream",
        "Cache-Control": "no-cache",
        "Connection": "keep-alive"
      }
    }
  )
})