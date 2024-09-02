import {
  AbilityAware,
  AbilityPluginBinding,
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';
import { authentication } from '@kit.AccountKit';
import { buffer, util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { http } from '@kit.NetworkKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { UIAbility } from '@kit.AbilityKit';


/** FlutterHarmonyLoginPlugin **/
export default class FlutterHarmonyLoginPlugin implements FlutterPlugin, MethodCallHandler, AbilityAware {
  private channel: MethodChannel | null = null;
  private clientID: String | null = null;
  private context: Context | null = null;

  constructor() {
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    this.context = binding.getAbility().context;
  }

  onDetachedFromAbility(): void {
    throw new Error('Method not implemented.');
  }

  getUniqueClassName(): string {
    return "FlutterHarmonyLoginPlugin"
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), "flutter_harmony_login");
    this.channel.setMethodCallHandler(this)
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null)
    }
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    console.debug(`incoming call:${call.method}`);
    if(call.method == 'init') {
      this.clientID = call.argument('clientID');
      console.debug(`set client id = ${this.clientID}`);
      result.success(true);
    } else if(call.method == 'getQuickLoginInfo') {
      this.getQuickLoginInfo(result);
    } else if (call.method == "quickLogin") {
      result.success(true)
    } else if(call.method == "login") {
      this.login(result);
    } else if(call.method == "getAuthorizationCode") {
      let scopes = call.argument('scopes') as string[];
      if(scopes) {
        this.getAuthorizationCode(scopes, result);
      }
      else {
        result.error(null, 'scopes not found', null);
      }
    }
    else {
      result.notImplemented()
    }
  }

  getAuthorizationCode(scopes: string[], result: MethodResult) {
  console.debug(`get authorization code, scopes=${JSON.stringify(scopes)}`);
    let authRequest = new authentication.HuaweiIDProvider().createAuthorizationWithHuaweiIDRequest();
    authRequest.scopes = scopes;
    authRequest.state = util.generateRandomUUID();
    authRequest.forceAuthorization = true;
    authRequest.permissions = ['serviceauthcode'];
    let controller = new authentication.AuthenticationController(this.context!);
    try {
      controller.executeRequest(authRequest, (error:BusinessError<Object>, data)=>{
        if(error) {
          console.debug(`get authorizationCode error:${JSON.stringify(error)}`);
          return;
        }
        let response = data as authentication.AuthorizationWithHuaweiIDResponse;
        let state = response.state;
        if(state !=  undefined && authRequest.state != state) {
          console.debug(`failed to authorize. The state is different, response.state = ${state}`);
          return ;
        }
        console.debug(`succeeded in authentication: ${JSON.stringify(response)}`);
        let authorizationCode = response.data!.authorizationCode;
        console.debug(`authorizationCode=${authorizationCode}`);
        result.success(authorizationCode);
        //请求access token\refresh token
      });
    } catch(error) {
      console.debug(`get authorizationCode failed ${JSON.stringify(error)}}`);
      result.error(null, JSON.stringify(error), null);
    }
  }

  getQuickLoginInfo(result: MethodResult) {
    let authRequest = new authentication.HuaweiIDProvider().createAuthorizationWithHuaweiIDRequest();
    authRequest.scopes = ['quickLoginAnonymousPhone', 'openid'];
    authRequest.state = util.generateRandomUUID();
    authRequest.forceAuthorization = false;
    let controller = new authentication.AuthenticationController();
    try{
      controller.executeRequest(authRequest).then((response: authentication.AuthorizationWithHuaweiIDResponse) => {
        let unionID = response.data?.unionID;
        let openID = response.data?.openID;
        let anonymousPhone = response.data?.extraInfo?.quickLoginAnonymousPhone;
        if(anonymousPhone) {
          result.success({
            "unionID": unionID,
            "openID": openID,
            "anonymousPhone": anonymousPhone
          });
        }
      }).catch((error: BusinessError)=>{
        console.debug(`get info error: ${JSON.stringify(error)}`);
        result.error(error.code.toString(), error.name, error.message);
      });
    } catch (error) {
      console.debug(`get info param error: ${JSON.stringify(error)}`);
    }

  }



  login(result: MethodResult) {
    let loginRequest = new authentication.HuaweiIDProvider().createLoginWithHuaweiIDRequest();
    loginRequest.state = util.generateRandomUUID();
    loginRequest.forceLogin = true;
    let controller = new authentication.AuthenticationController();
    try{
      controller.executeRequest(loginRequest).then(async (response: authentication.LoginWithHuaweiIDResponse) => {
        let data = response.data!;
        let authorizationCode = data.authorizationCode;
        let idToken = data.idToken;
        let openID = data.openID;
        let unionID = data.unionID;
        console.debug(`idToken=${idToken}`);
        if(idToken) {
          if(await this.decodeIdToken(idToken)) {
            result.success({
              "authorizationCode": authorizationCode,
              "idToken": idToken,
              "openID": openID,
              "unionID": unionID
            });
          } else {
            result.error("loginFailed", `登录失败`, null);
          }
        } else {
          result.error('loginFailed', "idToken缺失", null);
        }

      }).catch((error: BusinessError)=>{
        console.debug(`login error: ${JSON.stringify(error)}`);
        result.error(error.code.toString(), error.name, error.message);
      });
    } catch (error) {
      console.debug(`login param error: ${JSON.stringify(error)}`);
    }
  }

  decodeBase64(data: string): string {
    return buffer.from(data, 'base64').toString('utf8');
  }
  // 解析ID Token并验证
  async decodeIdToken(idToken: string): Promise<boolean> {
    const parts = idToken.split('.');
    if (parts.length !== 3) {
      return false;
    }
    let idTokenObj: Record<string, Object> = {};
    // ID Token头部
    idTokenObj['header'] = JSON.parse(this.decodeBase64(parts[0]));
    // ID Token负载
    idTokenObj['payload'] = JSON.parse(this.decodeBase64(parts[1]));
    // ID Token签名
    idTokenObj['signature'] = parts[2];
    let header: Record<string, string> = idTokenObj['header'] as Record<string, string>;
    // 从负载中解析出nonce等数据
    let payLoad: Record<string, string> = idTokenObj['payload'] as Record<string, string>;
    let nonce: string = payLoad['nonce'];
    console.debug(`header=${JSON.stringify(header)}, payload=${JSON.stringify(payLoad)}`);
    const ID_TOKEN_ISSUE: string = 'https://accounts.huawei.com';
    let iss: string = payLoad['iss'];
    let aud: string = payLoad['aud'];
    if(iss !== ID_TOKEN_ISSUE){
      // 验证失败，开发者处理失败场景
      console.debug('Failed to check iss');
      return false;
    }
    if(aud !== this.clientID){
      // 验证失败，开发者处理失败场景
      console.debug(`Failed to check aud, aud=${aud}, clientID=${this.clientID}`);
      return false;
    }


    // 验证签名
    return await this.checkSignature(idToken, header['kid'], header['alg']);
  }

  private stringToUint8Array(str: string): Uint8Array {
    let arr: number[] = [];
    for (let i = 0, j = str.length; i < j; ++i) {
      arr.push(str.charCodeAt(i));
    }
    let tmpUint8Array: Uint8Array = new Uint8Array(arr);
    return tmpUint8Array;
  }
  // 验签方法
  private async checkSignature(idToken: string, kid: string, alg: string): Promise<boolean> {
    if (!idToken) {
      return false;
    }
    const parts = idToken.split('.');
    if (parts.length !== 3) {
      return false;
    }
    const url = 'https://oauth-login.cloud.huawei.com/oauth2/v3/certs';
    // 创建http请求，应用需在module.json5文件中先申请“ohos.permission.INTERNET”网络权限，请求才能发送成功
    let httpRequest = http.createHttp();
    let response = await httpRequest.request(url).catch((error: BusinessError)=>{
      console.debug(`Failed to httpRequest. Code: ${error.code}, message: ${error.message}`);
      httpRequest.destroy();
    });
    if(response === null) {
      return false;
    }
    let data = response as http.HttpResponse;
    let nStr = '';
    let eStr = '';
    let keys: object[] = JSON.parse(data.result as string)["keys"];
    for (let item of keys) {
      if (kid === item['kid']) {
        nStr = item['n'];
        eStr = item['e'];
        break;
      }
    }
    let nBigInt = '0x' + buffer.from(nStr, "base64url").toString('hex');
    let eBigInt = '0x' + buffer.from(eStr, "base64url").toString('hex');
    let dsaCommonSpec: cryptoFramework.RSACommonParamsSpec = {
      algName: "RSA",
      specType: cryptoFramework.AsyKeySpecType.COMMON_PARAMS_SPEC,
      n: BigInt(nBigInt),
    }
    let rsaKeyPairSpec: cryptoFramework.RSAPubKeySpec = {
      algName: "RSA",
      specType: cryptoFramework.AsyKeySpecType.PUBLIC_KEY_SPEC,
      params: dsaCommonSpec,
      pk: BigInt(eBigInt),
    }
    let asyKeyGeneratorBySpec = cryptoFramework.createAsyKeyGeneratorBySpec(rsaKeyPairSpec);
    let publicKey = await asyKeyGeneratorBySpec.generatePubKey();
    if(publicKey === null) {
      return false;
    }

    let idTokenSign = parts[2];
    let idTokenSignArr: cryptoFramework.DataBlob = { data: new Uint8Array(buffer.from(idTokenSign, "base64url").buffer) };
    let _idToken = parts[0] + '.' + parts[1];
    let idTokenArr: cryptoFramework.DataBlob = { data: this.stringToUint8Array(_idToken) };
    let verifier = alg === 'PS256' ? cryptoFramework.createVerify("RSA2048|PSS|SHA256|MGF1_SHA256")
      : cryptoFramework.createVerify("RSA2048|PKCS1|SHA256");
    await verifier.init(publicKey).catch((error:BusinessError)=>{
      console.debug(`verify init error:${JSON.stringify(error)}`);
    });
    let verifyResult = await verifier.verify(idTokenArr, idTokenSignArr).catch((error:BusinessError)=>{
      console.debug(`verify error:${JSON.stringify(error)}`);
    });
    console.debug(`verify result = ${verifyResult}`);
    httpRequest.destroy();
    if(verifyResult) {
      return verifyResult;
    }
    return false;
  }
}