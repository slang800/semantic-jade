# Yade
This is a fork of Jade that removes a bunch of deps that are only needed for the Jade command-line tool. Since [Accord-CLI](https://github.com/carrot/accord-cli) already provides a CLI, and [Accord](https://github.com/jenius/accord) itself only uses Jade's JS API, all of those deps are dead-weight if you're using Jade with Accord.
