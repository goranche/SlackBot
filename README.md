# SlackBot

A Vapor enabled Slack bot component, which allows easy bot writing in Swift.

The code was based on the [Vapor slack-bot](https://github.com/vapor/slack-bot) project, but as projects like these tend to do, grew significantly from there... 🤓

It's not complete yet, neither in terms of functionality (the Slack API is huge, after all), nor in terms of usability / developer friendliness. The intention is to make it a clean Swift Package Manager package, which it kind of is already, but needs some more work.

That said, it can be used for testing, the bot is capable of receiving and sending messages from/to slack.

## Example

An example of how to use this package can be found [here](https://github.com/goranche/clockyBot).

## Known issues

There is a dependency on a Vapor feature that isn't publicly (in terms of protection level) available yet, but a [pull request](https://github.com/vapor/vapor/pull/786) has been submitted. (an explanation of the issue can be found [here](https://github.com/vapor/vapor/issues/785))
Until that is sorted out, you'll have to manually update the Vapor code (explained in a comment at the point where compilation will fail)

Some parts of the code could be done differently / simpler with better knowledge of code in the Vapor frameworks (mainly Node and Polymorphic).
Will be redone in the future.
