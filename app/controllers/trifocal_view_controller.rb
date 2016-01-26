class TrifocalViewController < UIViewController

  include DebugConcern

  def viewDidLoad
    super

    @setting = AppSetting.instance

    self.title = 'Trifocal'
    self.view.backgroundColor = UIColor.orangeColor

    menu_button = BW::UIBarButtonItem.styled(:plain, 'Done') { close }
    self.navigationItem.RightBarButtonItem = menu_button

    @switch = UISwitch.new.tap do |s|
      s.center = CGPointMake(Device.screen.width / 2, Device.screen.height / 2 - 100)
      s.on = @setting['trifocal']
      s.on :change { switchDidChange }
    end
    self.view << @switch

    @textFieid = UITextField.new.tap do |t|
      t.keyboardType = UIKeyboardTypeNumberPad
      t.frame = CGRectMake(200, Device.screen.height / 2 - 50, Device.screen.width - 400, 40)
      t.borderStyle = UITextBorderStyleRoundedRect
      t.font = UIFont.systemFontOfSize(24)
      t.textColor = UIColor.blackColor
      t.textAlignment = UITextAlignmentCenter
      t.enabled = @setting['trifocal']
      t.text = @setting['trifocalMiddleValue'].to_s
    end
    self.view << @textFieid

  end

  def close
    save_defaults
    self.navigationController.popViewControllerAnimated(true)
  end

  def save_defaults
    @setting['trifocal'] = @switch.on?
    @setting['trifocalMiddleValue'] = @textFieid.text.match(/\A\d+\z/) ? @textFieid.text.to_i : nil
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
