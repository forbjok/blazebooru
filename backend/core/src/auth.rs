use anyhow::anyhow;
use argon2::{Argon2, PasswordHash, PasswordVerifier};
use serde::{de::DeserializeOwned, Serialize};
use uuid::Uuid;

use blazebooru_models::local as lm;

use super::BlazeBooruCore;

impl BlazeBooruCore {
    pub async fn login(
        &self,
        user_name: &str,
        password: &str,
    ) -> Result<Option<lm::User>, anyhow::Error> {
        if let Some(user) = self.store.get_user_by_name(user_name).await? {
            let password_hash = PasswordHash::new(user.password_hash.as_ref().unwrap())
                .map_err(|err| anyhow!("{err}"))?;

            let argon2 = Argon2::default();
            if argon2
                .verify_password(password.as_bytes(), &password_hash)
                .is_ok()
            {
                Ok(Some(lm::User::from(user)))
            } else {
                Ok(None)
            }
        } else {
            Ok(None)
        }
    }

    pub async fn logout(&self, session: i64) -> Result<(), anyhow::Error> {
        self.store.invalidate_session(session).await
    }

    pub async fn create_refresh_token<T: Serialize>(
        &self,
        claims: &T,
    ) -> Result<lm::CreateRefreshTokenResult, anyhow::Error> {
        let json = serde_json::to_string(claims)?;

        Ok(lm::CreateRefreshTokenResult::from(
            self.store.create_refresh_token(&json).await?,
        ))
    }

    pub async fn refresh_refresh_token<T: DeserializeOwned>(
        &self,
        token: Uuid,
    ) -> Result<Option<lm::RefreshRefreshTokenResult<T>>, anyhow::Error> {
        let r = self.store.refresh_refresh_token(token).await?;
        if let (Some(token), Some(session), Some(claims)) = (r.token, r.session, r.claims) {
            Ok(Some(lm::RefreshRefreshTokenResult {
                token,
                session,
                claims: serde_json::from_str(&claims)?,
            }))
        } else {
            Ok(None)
        }
    }
}
