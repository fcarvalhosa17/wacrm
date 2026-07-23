-- ============================================================
-- INVITE-ONLY SIGNUP
--
-- Enforces server-side (not just UI) that new accounts can only be
-- created with an unused, unexpired account_invitations.token_hash.
-- The client sends the raw invite token in
-- `options.data.invite_token` on `auth.signUp()`; this hook hashes
-- it the same way `hashInviteToken()` does (SHA-256 hex) and looks
-- it up.
--
-- Wire this up in Auth Hooks (Before User Created) → Postgres
-- function → public.hook_require_invite_token. Not automatic —
-- must be enabled once in the Supabase dashboard or via the
-- Management API.
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE OR REPLACE FUNCTION public.hook_require_invite_token(event jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_token text;
  v_hash text;
  v_valid int;
BEGIN
  v_token := event->'user'->'user_metadata'->>'invite_token';

  IF v_token IS NULL OR length(v_token) = 0 THEN
    RETURN jsonb_build_object(
      'error', jsonb_build_object(
        'http_code', 400,
        'message', 'Cadastro somente por convite. Peça um link de convite a um administrador da conta.'
      )
    );
  END IF;

  v_hash := encode(digest(v_token, 'sha256'), 'hex');

  SELECT count(*) INTO v_valid
  FROM public.account_invitations
  WHERE token_hash = v_hash
    AND accepted_at IS NULL
    AND expires_at > now();

  IF v_valid = 0 THEN
    RETURN jsonb_build_object(
      'error', jsonb_build_object(
        'http_code', 400,
        'message', 'Convite inválido, já utilizado ou expirado.'
      )
    );
  END IF;

  RETURN '{}'::jsonb;
END;
$$;

GRANT EXECUTE ON FUNCTION public.hook_require_invite_token TO supabase_auth_admin;
REVOKE EXECUTE ON FUNCTION public.hook_require_invite_token FROM authenticated, anon, public;
