XikBot
======

A Twitch IRC bot, written in Elixir.

## Setup

```
$ git clone https://github.com/michaelowens/xikbot && cd xikbot # or use a fork
$ cp config/config.exs.example config/config.exs
$ vim config/config.exs # Modify the config to your needs
$ mix do install # installs Amnesia database schema
$ iex -S mix # run
```

## Testing

I'm very new to Elixir and ran into issues with the Supervisor in combination
with ExUnit. I'm not quite sure how to fix this yet... If you want, you can try
to run the tests with the following command:

```
$ mix test --no-start
```

I want to be able to run tests with the `--no-start` argument as we need to mock
`ExIrc` before it connects (so we don't need an active connection to run tests).

If you have an idea on how to fix this, please let me know.
