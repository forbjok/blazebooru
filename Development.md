## Backend

### Setting up postgresql

Blazebooru uses postgresql and cannot be used without it. The following uses environment variable to set key variables.

Run the following commands to setup postgresql. It is assumed postgresql is installed and commands are in `$PATH`

```bash
# create the database with the user blazebooru. use --pwprompt to prompt for password
initdb ./postgres -U blazebooru 
# start the database
pg_ctl -D ./postgres -l ./postgres/log -o "-k ''" start 

cd backend/store
#use blazebooru:PASSWORD@localhost if you have set a password.
DATABASE_URL="postgres://blazebooru@localhost:5432/blazebooru" sqlx database setup
cd ../
#run the server
BLAZEBOORU_FILES_PATH="/tmp/blaze" DATABASE_URL="postgres://blazebooru@localhost:5432/blazebooru" BLAZEBOORU_JWT_SECRET="sekrit"  cargo run --release -- server --serve-files
```

If you don't have sqlx already installed look [here](https://github.com/launchbadge/sqlx/blob/main/sqlx-cli/README.md#install)

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