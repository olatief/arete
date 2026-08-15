import { createConsumer } from "@rails/actioncable"

const consumer = createConsumer()

// Diagnostic/system-test hook: lets a console (or Capybara) sever and reopen
// the websocket to exercise the reconnect/resync path.
window.cableConsumer = consumer

export default consumer
