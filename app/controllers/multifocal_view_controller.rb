class MultifocalViewController < UIViewController

  include DebugConcern

  def viewDidLoad
    super

    @setting = AppSetting.instance

    self.title = 'Multifocal'
    self.view.backgroundColor = UIColor.blueColor

    menu_button = BW::UIBarButtonItem.styled(:plain, 'Done') { close }
    self.navigationItem.RightBarButtonItem = menu_button

    @switch = UISwitch.new.tap do |s|
      s.center = CGPointMake(Device.screen.width / 2, Device.screen.height / 2 - 100)
      s.on = @setting['multifocal']
      s.on :change { switchDidChange }
    end
    self.view << @switch

    @textFieid = UITextField.new.tap do |t|
      t.keyboardType = UIKeyboardTypeNumberPad
      t.frame = CGRectMake(200, Device.screen.height / 2 - 50, Device.screen.width - 400, 40)
      # t.clearButtonMode = UITextFieldViewModeWhiteEditing
      t.borderStyle = UITextBorderStyleRoundedRect
      t.font = UIFont.systemFontOfSize(24)
      t.textColor = UIColor.blackColor
      t.textAlignment = UITextAlignmentCenter
      t.enabled = @setting['multifocal']
      t.text = @setting['multifocalMiddleValue'].to_s
    end
    self.view << @textFieid

  end

  def close
    save_defaults
    self.navigationController.popViewControllerAnimated(true)
  end

  def save_defaults
    @setting['multifocal'] = @switch.on?
    @setting['multifocalMiddleValue'] = @textFieid.text.match(/\A\d+\z/) ? @textFieid.text.to_i : nil
  end

  def switchDidChange
    @textFieid.enabled = if @switch.on?
      @textFieid.becomeFirstResponder
      true
    else
      self.view.endEditing(true)
      @textFieid.text = ''
      false
    end
  end

end
