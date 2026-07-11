require 'rails_helper'

RSpec.describe "Global focus styles", type: :system do
  it "removes link underline and the default input outline (US1)" do
    visit new_session_path # sign-in page has links + inputs

    decoration = page.evaluate_script(
      "getComputedStyle(document.querySelector('.auth__link')).textDecorationLine"
    )
    expect(decoration).to eq("none")

    page.execute_script("document.querySelector('input').focus()")
    outline = page.evaluate_script(
      "getComputedStyle(document.querySelector('input:focus')).outlineStyle"
    )
    expect(outline).to eq("none")
  end
end
