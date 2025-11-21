import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req) => {
  // Get API key from environment variables (set via supabase secrets)
  const PERPLEXITY_API_KEY = Deno.env.get('PERPLEXITY_API_KEY')

  if (!PERPLEXITY_API_KEY) {
    return new Response(
      JSON.stringify({ error: 'API key not configured' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }

  try {
    const requestBody = await req.json()

    // Validate request
    if (!requestBody.message) {
      return new Response(
        JSON.stringify({ error: 'Message is required' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Check if streaming is requested
    const isStreaming = requestBody.stream === true

    // Build Perplexity API request
    const perplexityRequest = {
      model: requestBody.model || 'sonar',
      messages: [
        {
          role: 'system',
          content: requestBody.systemPrompt || 'You are a helpful AI assistant.'
        },
        {
          role: 'user',
          content: requestBody.message
        }
      ],
      max_tokens: requestBody.maxTokens || 500,
      temperature: requestBody.temperature || 0.7,
      stream: isStreaming, // Enable streaming if requested
    }

    // Call Perplexity API
    const response = await fetch('https://api.perplexity.ai/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${PERPLEXITY_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(perplexityRequest),
    })

    if (!response.ok) {
      const errorText = await response.text()
      console.error('Perplexity API error:', response.status, errorText)

      return new Response(
        JSON.stringify({
          error: 'AI service error',
          status: response.status
        }),
        {
          status: response.status,
          headers: { 'Content-Type': 'application/json' }
        }
      )
    }

    if (isStreaming) {
      // Handle streaming response
      const reader = response.body?.getReader()
      const encoder = new TextEncoder()

      return new Response(
        new ReadableStream({
          async start(controller) {
            try {
              while (true) {
                const { done, value } = await reader!.read()
                if (done) break

                const chunk = new TextDecoder().decode(value)
                const lines = chunk.split('\n')

                for (const line of lines) {
                  if (line.startsWith('data: ')) {
                    const data = line.slice(6)
                    if (data === '[DONE]') {
                      controller.enqueue(encoder.encode('data: [DONE]\n\n'))
                      break
                    }

                    try {
                      const parsed = JSON.parse(data)
                      const content = parsed.choices?.[0]?.delta?.content || ''
                      if (content) {
                        controller.enqueue(encoder.encode(`data: ${JSON.stringify({
                          content: content,
                          done: false
                        })}\n\n`))
                      }
                    } catch (e) {
                      // Skip invalid JSON
                    }
                  }
                }
              }

              // Send final done message
              controller.enqueue(encoder.encode('data: [DONE]\n\n'))
              controller.close()
            } catch (error) {
              controller.error(error)
            }
          }
        }),
        {
          headers: {
            'Content-Type': 'text/event-stream',
            'Cache-Control': 'no-cache',
            'Connection': 'keep-alive',
          }
        }
      )
    } else {
      // Handle regular response
      const data = await response.json()

      // Return the AI response
      return new Response(
        JSON.stringify({
          content: data.choices?.[0]?.message?.content || 'No response generated',
          usage: data.usage,
          model: data.model,
        }),
        {
          headers: { 'Content-Type': 'application/json' }
        }
      )
    }

  } catch (error) {
    console.error('Edge Function error:', error)

    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      {
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      }
    )
  }
})