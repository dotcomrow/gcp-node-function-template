import * as ff from '@google-cloud/functions-framework';
import { serializeError } from "serialize-error";
import { GCPLogger } from "npm-gcp-logging";
import { GCPAccessToken } from "npm-gcp-token";

interface PubSubData {
  subscription: string;
  message: {
    messageId: string;
    publishTime: string;
    data: string;
    attributes?: {[key: string]: string};
  };
}

ff.cloudEvent<PubSubData>('onMessage', async ce => {
  try {
    console.log(ce.data?.message.messageId);
  } catch (e) {
    if (!process.env.GCP_LOGGING_CREDENTIALS) {
      console.log("GCP_LOGGING_CREDENTIALS is not defined");
      return;
    }
    
    if (!process.env.GCP_LOGGING_PROJECT_ID) {
      console.log("GCP_LOGGING_PROJECT_ID is not defined");
      return;
    }

    if (!process.env.K_SERVICE) {
      console.log("K_SERVICE is not defined");
      return;
    }

    var logging_token = await new GCPAccessToken(
      process.env.GCP_LOGGING_CREDENTIALS
    ).getAccessToken("https://www.googleapis.com/auth/logging.write");
    const responseError = serializeError(e);
      await GCPLogger.logEntry(
        process.env.GCP_LOGGING_PROJECT_ID,
        logging_token.access_token,
        process.env.K_SERVICE,
        [
          {
            severity: "ERROR",
            // textPayload: message,
            jsonPayload: {
              responseError,
            },
          },
        ]
      );
    return;
  }
});