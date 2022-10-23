use blazebooru_models::export as em;
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
            id: u.id,
            created_at: u.created_at,
            updated_at: u.updated_at,
            name: u.name,
        }
    }
}

impl From<dbm::User> for vm::User {
    fn from(u: dbm::User) -> Self {
        vm::User {
            id: u.id,
            created_at: u.created_at,
            name: u.name,
            rank: u.rank,
        }
    }
}

impl From<dbm::ViewPost> for em::Post {
    fn from(p: dbm::ViewPost) -> Self {
        em::Post {
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
            tags: p.tags.unwrap(),
        }
    }
}

impl From<dbm::ViewPost> for vm::Post {
    fn from(p: dbm::ViewPost) -> Self {
        vm::Post {
            id: p.id.unwrap(),
            created_at: p.created_at.unwrap(),
            user_id: p.user_id.unwrap(),
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
            tags: p.tags.unwrap(),
        }
    }
}

impl From<dbm::PostComment> for vm::Comment {
    fn from(p: dbm::PostComment) -> Self {
        vm::Comment {
            id: p.id,
            created_at: p.created_at,
            updated_at: p.updated_at,
            user_id: p.user_id,
            user_name: p.user_name,
            comment: p.comment,
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

impl From<dbm::ViewTag> for vm::Tag {
    fn from(t: dbm::ViewTag) -> Self {
        vm::Tag {
            id: t.id.unwrap(),
            tag: t.tag.unwrap(),
            alias_of_tag: t.alias_of_tag,
            implied_tags: t.implied_tags.unwrap(),
        }
    }
}

impl From<vm::UpdateTag> for dbm::UpdateTag {
    fn from(t: vm::UpdateTag) -> Self {
        dbm::UpdateTag {
            alias_of_tag: t.alias_of_tag,
            add_implied_tags: t.add_implied_tags,
            remove_implied_tags: t.remove_implied_tags,
        }
    }
}

pub fn dbm_update_post_from_vm(id: i32, p: vm::UpdatePost) -> dbm::UpdatePost {
    dbm::UpdatePost {
        id: Some(id),
        title: p.title,
        description: p.description,
        source: p.source,
        add_tags: p.add_tags,
        remove_tags: p.remove_tags,
    }
}
