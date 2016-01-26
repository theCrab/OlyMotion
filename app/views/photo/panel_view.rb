class PanelView < UIView
  include DebugConcern

  COMPONENTS = [
    {
      uiType: :button,
      title: '☓',
      action: :closePhotoView,
      outlet: :closePhotoViewButton
    },
    {
      uiType: :label,
      text: 'alert',
      outlet: :alertLabel
    },
    {
      uiType: :button,
      title: "WB\nAuto",
      action: :toggleWhiteBalance,
      outlet: :toggleWhiteBalanceButton
    },
    {
      uiType: :button,
      title: 'P',
      action: :toggleTakeMode,
      outlet: :toggleTakeModeButton
    },
    {
      uiType: :label,
      text: "SHTR\nN/A",
      outlet: :shutterSpeedLabel
    },
    {
      uiType: :label,
      text: "ISO\nN/A",
      outlet: :isoSensitivityLabel
    },
    {
      uiType: :label,
      text: "APTR\nN/A",
      outlet: :apertureValueLabel
    },
    {
      uiType: :label,
      text: "XPSR\nN/A",
      outlet: :exposureCompensationLabel
    },
    {
      uiType: :button,
      title: 'S-AF',
      action: :toggleFocusMode,
      outlet: :toggleFocusModeButton
    },
    {
      uiType: :button,
      title: "AE\nUnlock",
      action: :toggleAeLockState,
      outlet: :toggleAeLockStateButton
    }
  ]

  def initWithFrame(frame)
    super(frame)
    @camera = AppCamera.instance
    @setting = AppSetting.instance
    @outlets = {}
    self.backgroundColor = UIColor.darkGrayColor
    @containers = []
    @components = []
    6.times do |i|
      @containers << UIView.new
      @components[i] = []
    end
    COMPONENTS.each_with_index do |component, index|
      @outlets[component[:outlet]] = case component[:uiType]
      when :button
        UIButton.rounded_rect.tap do |b|
          b.titleLabel.numberOfLines = 0
          b.setTitle(component[:title], forState:UIControlStateNormal)
          b.titleLabel.textAlignment = NSTextAlignmentCenter
          # b.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter
          b.on(:touch) { |event| send(component[:action]) }
        end
      when :label
        UILabel.new.tap do |l|
          l.numberOfLines = 0
          l.font = UIFont.systemFontOfSize(14)
          l.text = component[:text]
          l.textAlignment = NSTextAlignmentCenter
          l.textColor = UIColor.whiteColor
        end
      end
      @components[index / 2] << @outlets[component[:outlet]]
    end

    panelWidth = Device.screen.width - Device.screen.height * 1.5
    componentWidth = (panelWidth - 2 - 2 - 2) / 2
    5.times do |index|
      @containers[index] << @components[index][0]
      @containers[index] << @components[index][1]
      Motion::Layout.new do |layout|
        layout.view @containers[index]
        layout.subviews component0: @components[index][0], component1: @components[index][1]
        layout.vertical "|[component0]|"
        layout.vertical "|[component1]|"
        layout.horizontal "|-2-[component0(#{componentWidth})]-2-[component1(#{componentWidth})]-2-|"
      end
      self << @containers[index]
    end

    @outlets[:focalLengthSlider] = UISlider.new.tap do |s|
      s.continuous = false
    end
    @outlets[:focalLengthLabel] = UILabel.new.tap do |l|
      l.font = UIFont.systemFontOfSize(10)
      l.text = 'N/A'
      l.textAlignment = NSTextAlignmentCenter
      l.textColor = UIColor.whiteColor
    end
    @containers[5] << @outlets[:focalLengthSlider]
    @containers[5] << @outlets[:focalLengthLabel]
    initFocalLengthSlider
    Motion::Layout.new do |layout|
      layout.view @containers[5]
      layout.subviews slider: @outlets[:focalLengthSlider], label: @outlets[:focalLengthLabel]
      layout.vertical "|[slider][label]|"
      layout.horizontal "|[slider]|"
      layout.horizontal "|[label]|"
    end
    self << @containers[5]

    @releaseButton = UIButton.buttonWithType(UIButtonTypeSystem)
    @releaseButton.setTitle("写", forState:UIControlStateNormal)
    @releaseButton.addTarget(self, action:"releaseShutter", forControlEvents:UIControlEventTouchUpInside)
    self << @releaseButton

    Motion::Layout.new do |layout|
      layout.view self
      layout.subviews releaseButton: @releaseButton, ab: @containers[0], cd: @containers[1], ef: @containers[2], gh: @containers[3], ij: @containers[4], kl: @containers[5]
      layout.vertical "|[ab][cd(==ab)][ef(==ab)]-[releaseButton(==ab)]-[gh(==ab)][ij(==ab)][kl(==ab)]|"
      layout.horizontal "|[ab]|"
      layout.horizontal "|[cd]|"
      layout.horizontal "|[ef]|"
      layout.horizontal "|[releaseButton]|"
      layout.horizontal "|[gh]|"
      layout.horizontal "|[ij]|"
      layout.horizontal "|-2-[kl]-10-|"
    end

    self
  end

  def initFocalLengthSlider
    @focalLengthSliderValue = {}
    @focalLengthSliderValue[:s] = @camera.minimumFocalLength
    @focalLengthSliderValue[:l] = @camera.maximumFocalLength
    if @focalLengthSliderValue[:s] == @focalLengthSliderValue[:l]
      @outlets[:focalLengthSlider].enabled = false
    else
      @outlets[:focalLengthSlider].enabled = true
      @focalLengthSliderValue[:m] = if (@focalLengthSliderValue[:s]..@focalLengthSliderValue[:l]).include?(@setting['multifocalMiddleValue'])
        @setting['multifocalMiddleValue']
      else
        (@focalLengthSliderValue[:s] + @focalLengthSliderValue[:l]) / 2
      end
      @focalLengthSliderValue[:threshold_s] = @focalLengthSliderValue[:s] + (@focalLengthSliderValue[:m] - @focalLengthSliderValue[:s]) / 3
      @focalLengthSliderValue[:threshold_l] = @focalLengthSliderValue[:l] - (@focalLengthSliderValue[:l] - @focalLengthSliderValue[:m]) / 3
      @outlets[:focalLengthSlider].minimumValue = @focalLengthSliderValue[:s]
      @outlets[:focalLengthSlider].maximumValue = @focalLengthSliderValue[:l]
      @outlets[:focalLengthSlider].addTarget(self, action:'sliderUpdate:', forControlEvents:UIControlEventValueChanged)
      if @setting['multifocal']
        @outlets[:focalLengthSlider].setMinimumTrackTintColor(UIColor.orangeColor)
        @outlets[:focalLengthSlider].setMaximumTrackTintColor(UIColor.orangeColor)
      else
        @outlets[:focalLengthSlider].setMinimumTrackTintColor(UIColor.greenColor)
        @outlets[:focalLengthSlider].setMaximumTrackTintColor(UIColor.greenColor)
      end
      @outlets[:focalLengthSlider].value = @camera.actualFocalLength
    end
    @outlets[:focalLengthLabel].text = "#{@camera.actualFocalLength}mm"
  end

  def sliderUpdate(slider)
    slider.value = if @setting['multifocal']
      case slider.value
      when (@focalLengthSliderValue[:s]..@focalLengthSliderValue[:threshold_s])
        @focalLengthSliderValue[:s]
      when (@focalLengthSliderValue[:threshold_l]..@focalLengthSliderValue[:l])
        @focalLengthSliderValue[:l]
      else
        @focalLengthSliderValue[:m]
      end
    else
      slider.value.round
    end
    @outlets[:focalLengthLabel].text = "#{slider.value}mm"
  end

  def releaseShutter
  end

  def closePhotoView
    NSNotificationCenter.defaultCenter.postNotificationName('PhotoViewCloseButtonWasTapped', object:self)
  end

  def updateApertureValueLabel
    actualApertureValue = @camera.actualApertureValue.match(/<APERTURE\/([^>]+)>/).try(:[], 1)
    @outlets[:apertureValueLabel].text = actualApertureValue ? "APTR\n#{actualApertureValue}" : "APTR\nN/A"
  end

  def updateShutterSpeedLabel
    actualShutterSpeed = @camera.actualShutterSpeed.match(/<SHUTTER\/([^>]+)>/).try(:[], 1)
    @outlets[:shutterSpeedLabel].text = actualShutterSpeed ? "SHTR\n#{actualShutterSpeed}" : "SHTR\nN/A"
  end

  def updateExposureCompensationLabel
    actualExposureCompensation = @camera.actualExposureCompensation.match(/<EXPREV\/([^>]+)>/).try(:[], 1)
    @outlets[:exposureCompensationLabel].text = actualExposureCompensation ? "XPSR\n#{actualExposureCompensation}" : "XPSR\nN/A"
  end

  def updateIsoSensitivityLabel
    actualIsoSensitivity = @camera.actualIsoSensitivity.match(/<ISO\/([^>]+)>/).try(:[], 1)
    @outlets[:isoSensitivityLabel].text = actualIsoSensitivity ? "ISO\n#{actualIsoSensitivity}" : "ISO\nN/A"
  end

  def updateToggler(key, index)
    @outlets[key].setTitle(PhotoViewController::TOGGLERS[key][:titles][index], forState:UIControlStateNormal)
  end

  def toggleFocusMode
    NSNotificationCenter.defaultCenter.postNotificationName('ToggleFocusModeButtonWasTapped', object:self)
  end

  def toggleWhiteBalance
    NSNotificationCenter.defaultCenter.postNotificationName('ToggleWhiteBalanceButtonWasTapped', object:self)
  end

  def toggleTakeMode
    NSNotificationCenter.defaultCenter.postNotificationName('ToggleTakeModeButtonWasTapped', object:self)
  end

  def toggleAeLockState
    NSNotificationCenter.defaultCenter.postNotificationName('ToggleAeLockStateButtonWasTapped', object:self)
  end

end
