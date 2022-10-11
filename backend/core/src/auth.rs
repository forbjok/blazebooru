use std::net::IpAddr;

use anyhow::anyhow;
use argon2::{Argon2, PasswordHash, PasswordVerifier};
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
            let password_hash =
                PasswordHash::new(&user.password_hash).map_err(|err| anyhow!("{err}"))?;

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

    pub async fn create_refresh_token(
        &self,
        user_id: i32,
        ip: IpAddr,
    ) -> Result<lm::CreateRefreshTokenResult, anyhow::Error> {
        Ok(lm::CreateRefreshTokenResult::from(
            self.store.create_refresh_token(user_id, ip).await?,
        ))
    }

    pub async fn refresh_refresh_token(
        &self,
        token: Uuid,
        ip: IpAddr,
    ) -> Result<Option<lm::RefreshRefreshTokenResult>, anyhow::Error> {
        let r = self.store.refresh_refresh_token(token, ip).await?;
        if let (Some(token), Some(session), Some(user_id)) = (r.token, r.session, r.user_id) {
            Ok(Some(lm::RefreshRefreshTokenResult {
                token,
                session,
                user_id,
            }))
        } else {
            Ok(None)
        }
    }
}
