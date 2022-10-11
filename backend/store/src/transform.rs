use blazebooru_models::local as lm;
use blazebooru_models::view as vm;

use crate::models as dbm;

impl From<dbm::CreateRefreshTokenResult> for lm::CreateRefreshTokenResult {
    fn from(r: dbm::CreateRefreshTokenResult) -> Self {
        lm::CreateRefreshTokenResult {
            token: r.token.unwrap(),
            session: r.session.unwrap(),
        }
    }
}

impl From<dbm::User> for lm::User {
    fn from(u: dbm::User) -> Self {
        lm::User {
            id: u.id.unwrap(),
            created_at: u.created_at.unwrap(),
            updated_at: u.updated_at.unwrap(),
            name: u.name.unwrap(),
        }
    }
}

impl From<dbm::User> for vm::User {
    fn from(u: dbm::User) -> Self {
        vm::User {
            id: u.id.unwrap(),
            created_at: u.created_at.unwrap(),
            name: u.name.unwrap(),
        }
    }
}

impl From<dbm::ViewPost> for vm::Post {
    fn from(p: dbm::ViewPost) -> Self {
        vm::Post {
            id: p.id.unwrap(),
            created_at: p.created_at.unwrap(),
            user_name: p.user_name.unwrap(),
            title: p.title,
            description: p.description,
            source: p.source,
            filename: p.filename.unwrap(),
            size: p.size.unwrap(),
            width: p.width.unwrap(),
            height: p.height.unwrap(),
            hash: p.hash.unwrap(),
            ext: p.ext.unwrap(),
            tn_ext: p.tn_ext.unwrap(),
            tags: p.tags,
        }
    }
}

impl From<dbm::PageInfo> for vm::PageInfo {
    fn from(p: dbm::PageInfo) -> Self {
        vm::PageInfo {
            no: p.no.unwrap(),
            start_id: p.start_id.unwrap(),
        }
    }
}

impl From<vm::PageInfo> for dbm::PageInfo {
    fn from(p: vm::PageInfo) -> Self {
        dbm::PageInfo {
            no: Some(p.no),
            start_id: Some(p.start_id),
        }
    }
}
