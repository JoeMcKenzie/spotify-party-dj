# spotify-party-dj
Require To Run:
You need to install NPM, Docker Desktop, and you need some database manager

When using the project for the first time setup run these commands:

1) docker compose up -d           <-- starts docker database >
2) cd app                         <-- cd into the app/app folder  >
3) npm run db:init                <-- Custom script to setup database with all neccesary tables >
4) npm run dev                    <-- starts the website and can access on localhost:3000 if your not hosting, else you have to be on your network IP ( IP:3000 ).

How to find files:
In same directory as readme.md -> you will find the folder name sql turn in -> then in the app folder
you will find the rest of the project code
