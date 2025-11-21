-- Fix RLS policies to prevent infinite recursion
DROP POLICY IF EXISTS "Users can view participants in their conversations" ON public.participants;

-- Create corrected policies for participants table
CREATE POLICY "Users can view participants in their conversations" ON public.participants
  FOR SELECT USING (
    user_id = auth.uid()
  );

CREATE POLICY "Users can insert participants" ON public.participants
  FOR INSERT WITH CHECK (
    user_id = auth.uid()
  );

CREATE POLICY "Users can update participants" ON public.participants
  FOR UPDATE USING (
    user_id = auth.uid()
  );

-- Also fix conversation policies to prevent recursion
DROP POLICY IF EXISTS "Users can view conversations they participate in" ON public.conversations;

CREATE POLICY "Users can view conversations they participate in" ON public.conversations
  FOR SELECT USING (
    id IN (
      SELECT conversation_id FROM public.participants 
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update conversations" ON public.conversations
  FOR UPDATE USING (
    created_by = auth.uid()
  );

CREATE POLICY "Users can insert conversations" ON public.conversations
  FOR INSERT WITH CHECK (
    created_by = auth.uid()
  );