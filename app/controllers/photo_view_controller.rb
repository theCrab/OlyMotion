class PhotoViewController < UIViewController

  include UIViewControllerThreading
  include DebugConcern

  attr_accessor :previousRunMode

  def viewDidLoad
    super
    # ビューコントローラーの活動状態を初期化します。
    @startingActivity = false
    @previousRunMode = OLYCameraRunModeUnknown

    # 監視するカメラプロパティ名とそれに紐づいた対応処理(メソッド名)を対とする辞書を用意して、
    # Objective-CのKVOチックに、カメラプロパティに変化があったらその個別処理を呼び出せるようにしてみます。
    # @cameraPropertyObserver = {}
    # cameraPropertyObserver.setObject(NSStringFromSelector(@selector(didChangeAfLockState)), forKey:CameraPropertyAfLockState)
    # cameraPropertyObserver.setObject(NSStringFromSelector(@selector(didChangeAeLockState)), forKey:CameraPropertyAeLockState)
    # cameraPropertyObserver.setObject(NSStringFromSelector(@selector(didChangeAspectRatio)), forKey:CameraPropertyAspectRatio)
    @cameraPropertyObserver = {
      :CameraPropertyAfLockState => :didChangeAfLockState,
      :CameraPropertyAeLockState => :didChangeAeLockState,
      :CameraPropertyAspectRatio => :didChangeAspectRatio
    }
    # カメラプロパティ、カメラのプロパティを監視開始します。
    camera = AppCamera.instance
    camera.addCameraPropertyDelegate(self)
    # camera.addObserver(self, forKeyPath:'CameraPropertyDetectedHumanFaces', options:0, context:'didChangeDetectedHumanFaces:')
    # camera.addObserver(self, forKeyPath:'CameraPropertyRecordingElapsedTime', options:0, context:'didChangeRecordingElapsedTime:')
    # camera.addObserver(self, forKeyPath:'CameraPropertyMagnifyingLiveView', options:0, context:'didChangeMagnifyingLiveView:')
    # camera.addObserver(self, forKeyPath:'CameraPropertyMagnifyingLiveViewScale', options:0, context:'didChangeMagnifyingLiveViewScale:')
    setting = AppSetting.instance
    setting.addObserver(self, forKeyPath:"showLiveImageGrid", options:0, context:'didChangeShowLiveImageGrid:')

    @liveImageView = LiveImage.new
    self.view.addSubview(@liveImageView)
    Motion::Layout.new do |layout|
      layout.view self.view
      layout.subviews liveImageView: @liveImageView
      layout.vertical "|[liveImageView]|"
      layout.horizontal "|[liveImageView]|"
    end
  end

  def viewDidAppear(animated)
    super(animated)

    didStartActivity if isMovingToParentViewController
  end

  def viewWillAppear(animated)
    super(animated)
    navigationController.setToolbarHidden(true, animated:animated)
  end

  def viewDidDisappear(animated)
    super(animated)
    didFinishActivity if isMovingFromParentViewController
  end

  def viewDidLayoutSubviews
    super
    # コントロールのレイアウトがStroyboardで設定した初期状態になっている場合は非表示にします。
    # それ以外は、デバイスの縦置きや横置きに合うようにパネルの表示サイズを再配置します。
    # if (self.controlPanelVisibleStatus == ControlPanelVisibleStatusUnknown) {
    #   [self showPanel:ControlPanelVisibleStatusHidden animated:NO];
    # } else {
    #   [self showPanel:self.controlPanelVisibleStatus animated:NO];
    # }
  end

  def willTransitionToTraitCollection(collection, withTransitionCoordinator:coordinator)
    dp "collection=#{collection}"
    super(collection, withTransitionCoordinator:coordinator)

    # MARK: プログラムで変更したレイアウト制約をここで一度外しておかないとこのメソッドの後にAuto Layoutから警告を受けてしまいます。
    # デバイスが回転してレイアウトが変わる前の制約が何か邪魔しているっぽいです。
    # 以下はアドホックな対策ですが、他に良い方法が見つかりませんでした。
    # MARK: 他のビューコントローラーのビューが表示されている時に実施されないようにします。
    # これを考慮しないと制約が外れたままになってしまいこのビューコントローラーの表示が復帰した時に画面レイアウトが崩れてしまいます。
    if self.view.window
      self.controlPanelViewWidthConstraints.active = false
      self.controlPanelViewHeightConstraints.active = false
    end
  end

  #
  # 以上基礎実装
  #
  # 以下固有実装
  #

  # ビューコントローラーが画面を表示して活動を開始する時に呼び出されます。
  def didStartActivity
    if @startingActivity
      dp "すでに活動開始している場合は何もしません。"
      return nil
    end
    dp "撮影モードを開始します。"
    weakSelf = WeakRef.new(self)
    weakSelf.showProgressWhileExecutingBlock(true) do |progressView|
      dp "カメラを撮影モードに入れる前の準備をします。"
      camera = AppCamera.instance
      error = Pointer.new(:object)
      dp "ライブビュー自動開始を無効にします。"
      camera.autoStartLiveView = false
      dp "カメラを撮影モードに移行します。"
      weakSelf.previousRunMode = camera.runMode
      unless camera.changeRunMode(OLYCameraRunModeRecording, error:error)
        dp "モードを移行できませんでした。"
        weakSelf.alertOnMainThreadWithMessage(error.localizedDescription, title:"CouldNotStartRecordingMode")
        return
      end
      dp "Why the live view is already started?" if !camera.autoStartLiveView && camera.liveViewEnabled

      # # 最新スナップショットからカメラ設定を復元します。
      # setting = AppSetting.instance
      # if setting.keepLastCameraSetting
      #   snapshot = setting.latestSnapshotOfCameraSetting
      #   if snapshot
      #     NSDictionary *optimizedSnapshot = [camera optimizeSnapshotOfSetting:snapshot error:&error];
      #     if (optimizedSnapshot) {
      #       NSArray *exclude = @[
      #         CameraPropertyWifiCh, # Wi-Fiチャンネルの設定は復元しません。
      #       ];
      #       [weakSelf reportBlockSettingToProgress:progressView];
      #       if (![camera restoreSnapshotOfSetting:optimizedSnapshot exclude:exclude fallback:YES error:error)
      #         weakSelf.alertOnMainThreadWithMessage(error.localizedDescription, title:NSLocalizedString(@"$title:CouldNotRestoreLastestCameraSetting", @"RecordingViewController.didStartActivity")];
      #         # エラーを無視して続行します。
      #         dp "An error occurred, but ignores it."
      #       }
      #       progressView.mode = MBProgressHUDModeIndeterminate;
      #     } else {
      #       weakSelf.alertOnMainThreadWithMessage(error.localizedDescription, title:NSLocalizedString(@"$title:CouldNotRestoreLastestCameraSetting", @"RecordingViewController.didStartActivity")];
      #       # エラーを無視して続行します。
      #       dp "An error occurred, but ignores it."
      #     }
      #   } else {
      #     dp "No snapshots."
      #   }
      # }

      # # 現在位置を取得します。
      # RecordingLocationManager *locationManager = [[RecordingLocationManager alloc] init];
      # CLLocation *location = [locationManager currentLocation:10.0 error:&error];
      # if (location) {
      #   # カメラに位置情報を設定します。
      #   if (![camera setGeolocationWithCoreLocation:location error:error)
      #     # エラーを無視して続行します。
      #     dp "An error occurred, but ignores it."
      #   }
      # } else {
      #   # カメラに設定されている位置情報をクリアします。
      #   if (![camera clearGeolocation:&error]) {
      #     # エラーを無視して続行します。
      #     dp "An error occurred, but ignores it."
      #   }
      # }

      # ライブビューの表示を開始にします。
      # MARK: ライブビュー自動開始が有効でないなら、明示的にライブビューの表示開始を呼び出さなければなりません。
      camera.addLiveViewDelegate(weakSelf)
      camera.addRecordingDelegate(weakSelf)
      camera.addRecordingSupportsDelegate(weakSelf)
      camera.addTakingPictureDelegate(weakSelf)
      unless camera.startLiveView(error)
        weakSelf.alertOnMainThreadWithMessage(error.localizedDescription, title:"CouldNotStartRecordingMode")
        return
      end

      if camera.connectionType == OLYCameraConnectionTypeBluetoothLE
        dp "Bluetooth接続の場合はライブビュー画像は送信されてこないのでライブビュー画像なしのメッセージを表示します。"
        Dispatch::Queue.main.async {
          weakSelf.noLiveImageLabel.alpha = 0.0
          UIView.animateWithDuration(0.5, animations:-> do
            weakSelf.noLiveImageLabel.alpha = 1.0
          end)
        }
      end

      dp "デバイスのスリープを禁止します。"
      # MARK: Xcodeでケーブル接続してデバッグ実行しているとスリープは発動しないようです。
      UIApplication.sharedApplication.idleTimerDisabled = true
    end

    dp 'ビューコントローラーが活動を開始しました。'
    @startingActivity = true
  end

  # ビューコントローラーが画面を破棄して活動を完了する時に呼び出されます。
  def didFinishActivity
    dp "すでに活動停止している場合は何もしません。"
    return unless @startingActivity

    dp "パネル表示を終了します。"
    # [self.embeddedSPanelViewController didFinishActivity];
    # [self.embeddedEPanelViewController didFinishActivity];
    # [self.embeddedCPanelViewController didFinishActivity];
    # [self.embeddedAPanelViewController didFinishActivity];
    # [self.embeddedZPanelViewController didFinishActivity];
    # [self.embeddedVPanelViewController didFinishActivity];

    dp "撮影モードを終了します。"
    # MARK: weakなselfを使うとshowProgress:whileExecutingBlock:のブロックに到達する前に解放されてしまいます。
    weakSelf = WeakRef.new(self)
    weakSelf.showProgressWhileExecutingBlock(true) do |progressView|
      camera = AppCamera.instance
      dp "Why the live view is already stopped?" if !camera.autoStartLiveView && !camera.liveViewEnabled

      dp "ライブビューの表示を終了します。"
      # MARK: ライブビュー自動開始が有効でないなら、明示的にライブビューの表示停止を呼び出さなければなりません。
      camera.removeLiveViewDelegate(weakSelf)
      camera.removeRecordingDelegate(weakSelf)
      camera.removeRecordingSupportsDelegate(weakSelf)
      camera.removeTakingPictureDelegate(weakSelf)
      error = Pointer.new(:object)
      unless camera.stopLiveView(error)
        # エラーを無視して続行します。
        dp "An error occurred, but ignores it."
      end

      # # カメラ設定のスナップショットを取ります。
      # # FIXME: 撮影中にここに突入してきた場合にここで取ったカメラ設定のスナップショットが復元可能なのか分かりません...
      # setting = AppSetting.instance
      # if (setting.keepLastCameraSetting) {
      #   NSDictionary *snapshot = [camera createSnapshotOfSetting:&error];
      #   if (snapshot) {
      #     NSDictionary *optimizedSnapshot = [camera optimizeSnapshotOfSetting:snapshot error:&error];
      #     if (optimizedSnapshot) {
      #       # ユーザー設定の更新はメインスレッドで実行しないと接続画面で監視している人が困るようです。
      #       # (接続画面側の画面更新がとても遅れる)
      #       [weakSelf executeAsynchronousBlockOnMainThread:^{
      #         setting.latestSnapshotOfCameraSetting = optimizedSnapshot;
      #       }];
      #     } else {
      #       # エラーを無視して続行します。
      #       dp "An error occurred, but ignores it."
      #     }
      #   } else {
      #     # エラーを無視して続行します。
      #     dp "An error occurred, but ignores it."
      #   }
      # }

      dp "カメラを以前のモードに移行します。"
      unless camera.changeRunMode(weakSelf.previousRunMode, error:error)
        # エラーを無視して続行します。
        dp "An error occurred, but ignores it."
      end

      dp "デバイスのスリープを許可します。"
      UIApplication.sharedApplication.idleTimerDisabled = false
      dp "画面操作の後始末が完了しました。"
      weakSelf = nil
    end
    dp 'ビューコントローラーが活動を停止しました。'
    @startingActivity = false
  end

  def camera(camera, didUpdateLiveView:data, metadata:metadata)
    # dp "ライブビューの表示を最新の画像で更新します。"
    image = OLYCameraConvertDataToImage(data, metadata)
    if !@liveImageView.image && image
      dp "初めての表示更新の場合はフェードインアニメーションを伴います。"
      @liveImageView.alpha = 0.0
      @liveImageView.image = image
      UIView.animateWithDuration(0.5, animations:-> {
        @liveImageView.alpha = 1.0
      }, completion:->(finished) {
        dp "ライブビューの表示が始まったらグリッド表示を設定します。"
        setting = AppSetting.instance
        # @liveImageView.showGrid(setting.showLiveImageGrid)
      })
    else
      @liveImageView.image = image
    end
    # dp "ライブビューの回転方向をライブビュー拡大表示の全体図に反映します。"
    # self.liveImageOverallView.orientation = @liveImageView.image.imageOrientation;
  end

end