## Backend

### Working on blazebooru_store

When modifiying any sql in the `blazebooru_store` component, you need to have a running postgresql instance.
The `sqlx` framework uses this to validate your SQL at compile time.

If you don't intend to work on this component, you can [skip]() this section # TODO

Ensure you have a postgresql instance that is reachable form you development environment.
For convenience, a docker-compose file is provided.

Modify the default db location in the [env file](/backend/.env) to fit your db
Syntax is documented [here](https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-CONNSTRING)

Run the following commands to initlize the db.
```bash
cd backend/store
sqlx database setup
```

If you dont have sqlx already installed look [here](https://github.com/launchbadge/sqlx/blob/main/sqlx-cli/README.md#install)

### Without postgresql

Add `SQLX_OFFLINE=true` into [/backend/.env](/backend/.env)
Thats it, you now can build as normal.

If you at any time get build errors like
```bash
error: error communicating with database: Connection refused (os error 111)
 --> store/src/store/user.rs:7:20
  |
7 |         let post = sqlx::query_as_unchecked!(dbm::User, r#"SELECT * FROM create_user($1);"#, user)
  |                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  |
  = note: this error originates in the macro `$crate::sqlx_macros::expand_query` which comes from the expansion of the macro `sqlx::query_as_unchecked` (in Nightly builds, run with -Z macro-backtrace for more info)
```

then please follow the instructions in #TODO link


## Frontend

To build the site run

```bash
$ yarn install
$ yarn run build
```
The results are in the `dist/` folder.

For running the development webserver, run

```bash
$ yarn install
$ yarn run dev
```
