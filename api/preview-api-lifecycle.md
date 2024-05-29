# AKS Preview API Lifecycle

The AKS preview APIs (those ending in -preview) generally have a lifespan of ~1 year from their release date.
This means that you can expect the 2023-01-02-preview API to be deprecated somewhere around 2024-01-01. 

We love when people try our preview features and give us feedback, so we encourage you to use the preview APIs and the
tools built on them (such as the [AKS Preview CLI Extension](https://github.com/Azure/azure-cli-extensions/tree/main/src/aks-preview)).

After an API version is deprecated it will no longer function! We recommend you routinely:
- Update your ARM/BICEP templates using preview API versions to use the latest version of the preview API.
- Update your AKS preview CLI extension to the latest version.
- Update any preview SDKs or other tools built on the preview API to the latest version.

You should do this every 6-9 months. If you fail to do so, you will be notified that you are using a soon-to-be deprecated API version.

## Completed Deprecations

| API version        | Announce Date     | Deprecation Date  |
|--------------------|-------------------|-------------------|
| 2018-08-01-preview | March 7, 2023     | June 1, 2023      |
| 2021-11-01-preview | March 23, 2023    | July 1, 2023      |
| 2022-02-02-preview | April 27, 2023    | August 1, 2023    |
| 2022-01-02-preview | May 3, 2023       | Sept 1, 2023      |
| 2022-03-02-preview | May 3, 2023       | Sept 1, 2023      |
| 2022-04-02-preview | May 3, 2023       | Sept 1, 2023      |
| 2022-05-02-preview | May 3, 2023       | Sept 1, 2023      |
| 2022-06-02-preview | May 3, 2023       | Sept 1, 2023      |

## Upcoming Deprecations

| API version        | Announce Date     | Deprecation Date  |
|--------------------|-------------------|-------------------|
| 2022-07-02-preview | November 20, 2023 | February 14, 2024 |
| 2022-08-02-preview | March 27, 2024    | June 20, 2024     |
| 2022-08-03-preview | March 27, 2024    | June 20, 2024     |
| 2022-09-02-preview | March 27, 2024    | June 20, 2024     |
| 2022-10-02-preview | March 27, 2024    | June 20, 2024     |
| 2022-11-02-preview | March 27, 2024    | June 20, 2024     |
| 2023-01-02-preview | March 27, 2024    | June 20, 2024     |
| 2023-02-02-preview | March 27, 2024    | June 20, 2024     |

