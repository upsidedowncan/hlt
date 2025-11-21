-- Create typing status table for real-time typing indicators
CREATE TABLE IF NOT EXISTS public.typing_status (
  conversation_id UUID REFERENCES public.conversations(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  last_typed TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (conversation_id, user_id)
);

-- Enable RLS
ALTER TABLE public.typing_status ENABLE ROW LEVEL SECURITY;

-- Create policy for typing status
CREATE POLICY "Users can view typing status in their conversations" ON public.typing_status
  FOR SELECT USING (
    conversation_id IN (
      SELECT conversation_id FROM public.participants
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update their own typing status" ON public.typing_status
  FOR ALL USING (user_id = auth.uid());

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_typing_status_conversation_id ON public.typing_status(conversation_id);
CREATE INDEX IF NOT EXISTS idx_typing_status_last_typed ON public.typing_status(last_typed);