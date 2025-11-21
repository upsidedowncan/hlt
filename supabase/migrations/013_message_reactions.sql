-- Create table for message reactions
CREATE TABLE IF NOT EXISTS public.message_reactions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    emoji TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    UNIQUE(message_id, user_id, emoji)
);

-- Enable RLS
ALTER TABLE public.message_reactions ENABLE ROW LEVEL SECURITY;

-- Policies
-- Users can view reactions for messages in conversations they are part of
CREATE POLICY "Users can view reactions in their conversations"
    ON public.message_reactions FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.messages m
            JOIN public.participants p ON m.conversation_id = p.conversation_id
            WHERE m.id = message_reactions.message_id
            AND p.user_id = auth.uid()
        )
    );

-- Users can add their own reactions
CREATE POLICY "Users can add their own reactions"
    ON public.message_reactions FOR INSERT
    WITH CHECK (
        auth.uid() = user_id AND
        EXISTS (
            SELECT 1 FROM public.messages m
            JOIN public.participants p ON m.conversation_id = p.conversation_id
            WHERE m.id = message_id
            AND p.user_id = auth.uid()
        )
    );

-- Users can delete their own reactions
CREATE POLICY "Users can delete their own reactions"
    ON public.message_reactions FOR DELETE
    USING (auth.uid() = user_id);

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_message_reactions_message_id ON public.message_reactions(message_id);
