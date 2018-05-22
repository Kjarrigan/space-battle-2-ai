# Getting started

```bash
git clone https://github.com/atomicobject/space-battle-2.git
git clone ssh://git@git.hetzner.company:222/holger.arndt/space-battle-2.git holgers_ki

ruby holgers_ki/rts.rb &

cd space-battle-2/server
ruby src/app.rb
```

# Tip
   * Change server/src/game.rb STARTING_WORKERS => 1 to not get flooded with messages from the server!
