# spotify-party-dj

When using the project for the first time setup run these commands 

1) docker compose up -d           <-- starts docker database >
2) cd app                         <-- cd into the app/app folder  >
3) npm run db:init                <-- Custom script to setup database with all neccesary tables >
4) npm run db:seed                <-- this is optional but setups a mock jam right now so you don't need to make 2 accounts and test> TESTX is jame code
4) npm run dev                    <-- starts the website and can access on localhost:3000 >