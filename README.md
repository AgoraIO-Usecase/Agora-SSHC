
## Prerequisites

- Xcode 10.0+
- Physical iOS device (iPhone or iPad)
- iOS simulator is NOT supported

## Quick Start

This section shows you how to prepare, build, and run the sample application.

### Obtain an App Id

To build and run the sample application, get an App Id:

1. Create a developer account at [agora.io](https://dashboard.agora.io/signin/). Once you finish the signup process, you will be redirected to the Dashboard.
2. Navigate in the Dashboard tree on the left to **Projects** > **Project List**.
3. Save the **App Id** from the Dashboard for later use.
4. Generate a temp **Access Token** (valid for 24 hours) from dashboard page with given channel name, save for later use.

5. Open `OpenLive.xcodeproj` and edit the `KeyCenter.swift` file. In the `agoraKit` declaration, update `<#Your App Id#>` with your App Id, and assign the token variable with the temp Access Token generated from dashboard.

    ``` Swift
    static let AppId: String = <#Your App Id#>
    // assign token to nil if you have not enabled app certificate
    static var Token: String? = <#Temp Access Token#>
    ```

### Integrate the Agora Video SDK

1. SDK file is sdk.zip. Unzip the downloaded SDK package and copy the following files from the SDK `libs` folder into the sample application `OpenLive` folder.
    - `AograRtcKit2.framework`

2. Connect your iPhone or iPad device and run the project. Ensure a valid provisioning profile is applied or your project will not run.

### Add BGM file

1. you need to find 3 bgm mp3 file.
2. rename file to bgm1.mp3  bgm2.mp3 bgm3.mp3  and at those to project root path 
3. Open `OpenLive.xcodeproj`  and add those file to `Supporting Files`

## Contact Us

- For potential issues, take a look at our [FAQ](https://docs.agora.io/en/faq) first
- Dive into [Agora SDK Samples](https://github.com/AgoraIO) to see more tutorials
- Take a look at [Agora Use Case](https://github.com/AgoraIO-usecase) for more complicated real use case
- Repositories managed by developer communities can be found at [Agora Community](https://github.com/AgoraIO-Community)
- You can find full API documentation at [Document Center](https://docs.agora.io/en/)
- If you encounter problems during integration, you can ask question in [Stack Overflow](https://stackoverflow.com/questions/tagged/agora.io)
- You can file bugs about this sample at [issue](https://github.com/AgoraIO/Basic-Video-Broadcasting/issues)

## License

The MIT License (MIT)
