# -- Alps wants a Fernet key: 32 random bytes in URL-safe base64.
resource "random_bytes" "login_key" {
  length = 32
}
