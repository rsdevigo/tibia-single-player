# Client setup — OTClient Redemption

Players (and livestream spectators) connect with an OpenTibia client. We use
**OTClient Redemption**.

## 1. Download

- OTClient Redemption: https://github.com/opentibiabr/otclient
  (use a release build, or build from source per its README).

## 2. Game assets (`Tibia.dat` / `Tibia.spr`)

OTClient does not ship Tibia's graphics. The server is **Canary protocol 15.x**;
OTClient Redemption stores the matching `Tibia.dat` / `Tibia.spr` under its
`data/things/1100/` folder. Obtain those two files and place them there:

```
<OTClient-Redemption>/data/things/1100/Tibia.dat
<OTClient-Redemption>/data/things/1100/Tibia.spr
```

Where to obtain / how to extract them:
- https://downloads.ots.me/?sort_by=mod&sort_as=asc&dir=data/tibia-clients/dat_and_spr/
- https://github.com/dudantas/tibia-client/releases/tag/15.11.c9d1cf
- https://github.com/opentibiabr/otclient/wiki/Tutorial-Protocol-12.x-assets

> These are CipSoft assets — obtain them from a source you are entitled to; they
> are not redistributed here. (The Docker / one-install flow on the `dadsmmolab`
> branch can fetch and place them automatically from a `CLIENT_ASSETS_URL` you set.)

## 3. Point the client at your server

Edit the client's `init.lua` so it logs in through the web login service (this is
also what enables the `@livestream` spectator flow). For a **local** install use
`127.0.0.1`; for a remote server use its address.

```lua
-- updater / services
Services = {
    --updater = "http://127.0.0.1/api/updater.php",
    status = "http://127.0.0.1/login.php",
    websites = "http://127.0.0.1/?subtopic=accountmanagement",
    createAccount = "http://127.0.0.1/clientcreateaccount.php",
    getCoinsUrl = "http://127.0.0.1/?subtopic=shop&step=terms",
}

Servers_init = {
    ["http://127.0.0.1/login.php"] = {
        ["port"] = 80,
        ["protocol"] = 1511,
        ["httpLogin"] = true,
    }
}
```

`login.php` is the livestream-aware MyAAC login service shipped at
`deployment/web/login.php` (it intercepts the `@livestream` account and returns
the list of broadcasting characters). Make sure your web server is
serving it at the address above.

## 4. Spectate (livestream)

This fork uses Canary's built-in livestream instead of the original cast system.
A player starts broadcasting with `!livestream` (see the talkaction for options
such as a stream password). To watch, log in with the account name
**`@livestream`** and the stream password (empty if none) and pick a character.
Bots cannot be spectated: the livestream mirrors a real client connection.
