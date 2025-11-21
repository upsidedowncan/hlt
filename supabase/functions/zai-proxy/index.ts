import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req) => {
  // Get API key from environment variables (set via supabase secrets)
  const ZAI_API_KEY = Deno.env.get('ZAI_API_KEY')

  console.log('ZAI_API_KEY exists:', !!ZAI_API_KEY)
  console.log('ZAI_API_KEY length:', ZAI_API_KEY?.length)

  if (!ZAI_API_KEY) {
    return new Response(
      JSON.stringify({ error: 'API key not configured' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }

  // Check if API key has the expected format (UUID.secret)
  const keyParts = ZAI_API_KEY.split('.')
  console.log('API key parts:', keyParts.length)

  if (keyParts.length !== 2) {
    console.log('API key does not have expected format')
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

    // Build Z.ai API request (matching their documentation format)
    const zaiRequest = {
      model: requestBody.model || 'glm-4.5-flash',
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

    // Call Z.ai API
    console.log('Calling Z.ai API with key ending in:', ZAI_API_KEY.slice(-10))
    console.log('Request body:', JSON.stringify(zaiRequest, null, 2))

    const response = await fetch('https://api.z.ai/api/paas/v4/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${ZAI_API_KEY}`,
        'Content-Type': 'application/json',
        'Accept-Language': 'en-US,en',
      },
      body: JSON.stringify(zaiRequest),
    })

    if (!isStreaming) {
      // Handle regular response
      const data = await response.json()

      console.log('Z.ai API response data:', JSON.stringify(data, null, 2))

      // Z.ai API response format - try different possible structures
      let content = 'No response generated'
      let reasoning = null

      // Try standard OpenAI-like format
      if (data.choices?.[0]?.message?.content) {
        content = data.choices[0].message.content
        reasoning = data.choices[0].message.reasoning_content
      }
      // Try nested data format
      else if (data.data?.choices?.[0]?.message?.content) {
        content = data.data.choices[0].message.content
        reasoning = data.data.choices[0].message.reasoning_content
      }

      // If content is still empty but we have usage, the API might have responded with empty content
      if (content === 'No response generated' && data.usage) {
        content = '[API responded but content was empty - check logs]'
      }

      return new Response(
        JSON.stringify({
          content: content,
          reasoning: reasoning,
          usage: data.usage,
          model: data.model || zaiRequest.model,
        }),
        {
          headers: { 'Content-Type': 'application/json' }
        }
      )
    } else {
    // Handle streaming response
    const reader = response.body?.getReader()
    const encoder = new TextEncoder()

    return new Response(
      new ReadableStream({
        start(controller) {
          const processStream = async () => {
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
                      const reasoning_content = parsed.choices?.[0]?.delta?.reasoning_content

                      if (content || reasoning_content) {
                        controller.enqueue(encoder.encode(`data: ${JSON.stringify({
                          content: content,
                          reasoning_content: reasoning_content,
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

          processStream()
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
  }
    let content = 'No response generated'
    let reasoning = null

    // Try standard OpenAI-like format
    if (data.choices?.[0]?.message?.content) {
      content = data.choices[0].message.content
      reasoning = data.choices[0].message.reasoning_content
    }
    // Try nested data format
    else if (data.data?.choices?.[0]?.message?.content) {
      content = data.data.choices[0].message.content
      reasoning = data.data.choices[0].message.reasoning_content
    }

    // If content is still empty but we have usage, the API might have responded with empty content
    if (content === 'No response generated' && data.usage) {
      content = '[API responded but content was empty - check logs]'
    }

    return new Response(
      JSON.stringify({
        content: content,
        reasoning: reasoning,
        usage: data.usage,
        model: data.model || zaiRequest.model,
      }),
      {
        headers: { 'Content-Type': 'application/json' }
      }
    )
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