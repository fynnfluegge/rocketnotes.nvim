# rocketnotes.nvim

### How to run tests

1. Install busted

```
 luarocks install busted --local
```

2. Run tests with:

```
LUA_PATH="<PATH_TO_DIR>/rocketnotes.nvim/lua/?.lua;;" busted tests
```
