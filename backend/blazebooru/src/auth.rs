use chrono::{Duration, Utc};
use jsonwebtoken::{errors::ErrorKind, DecodingKey, EncodingKey, Header, Validation};
use serde::{de::DeserializeOwned, Deserialize, Serialize};
use thiserror::Error;

pub struct BlazeBooruAuth {
    keys: Keys,
}

#[derive(Debug, Error)]
pub enum AuthError {
    #[error("Token expired")]
    ExpiredToken,
    #[error("Error creating token")]
    TokenCreation,
    #[error("Invalid token")]
    InvalidToken,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct JwtClaims<C> {
    pub exp: usize,

    #[serde(flatten)]
    pub claims: C,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct AuthClaims {
    pub user_id: i32,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct SessionClaims {
    pub session: i64,
    #[serde(flatten)]
    pub claims: AuthClaims,
}

struct Keys {
    encoding: EncodingKey,
    decoding: DecodingKey,
}

impl BlazeBooruAuth {
    pub fn new(secret: &[u8]) -> Self {
        let keys = Keys::new(secret);

        Self { keys }
    }

    pub fn generate_token<T: Serialize>(&self, claims: &JwtClaims<T>) -> Result<String, AuthError> {
        let token = jsonwebtoken::encode(&Header::default(), &claims, &self.keys.encoding)
            .map_err(|_| AuthError::TokenCreation)?;

        Ok(token)
    }

    pub fn verify<T: DeserializeOwned>(&self, token: &str) -> Result<T, AuthError> {
        let token_data = jsonwebtoken::decode::<JwtClaims<T>>(token, &self.keys.decoding, &Validation::default())
            .map_err(|err| match err.kind() {
                ErrorKind::ExpiredSignature => AuthError::ExpiredToken,
                _ => AuthError::InvalidToken,
            })?;

        let JwtClaims { claims, .. } = token_data.claims;

        Ok(claims)
    }
}

impl Keys {
    fn new(secret: &[u8]) -> Self {
        Self {
            encoding: EncodingKey::from_secret(secret),
            decoding: DecodingKey::from_secret(secret),
        }
    }
}

impl<C> JwtClaims<C> {
    pub fn short(claims: C) -> Self {
        Self {
            exp: (Utc::now() + Duration::hours(1)).timestamp() as usize,
            claims,
        }
    }
}
