require "test_helper"

# Entrar y crear cuenta: panel de marca con el mensaje de KOVZU y el componente de Clerk.
class SessionsTest < ActionDispatch::IntegrationTest
  test "entrar muestra el panel de marca y monta el inicio de sesión de Clerk" do
    get sign_in_path
    assert_response :success

    assert_select ".kz-auth__aside h1", text: /Un pedido.\s*Una red coordinada/
    assert_select ".kz-auth__points li", 3
    assert_select "[data-controller=clerk][data-clerk-component-value=sign-in]"
    assert_select ".kz-appbar", 0
  end

  test "crear cuenta usa el mismo diseño con su propio mensaje" do
    get sign_up_path
    assert_response :success

    assert_select ".kz-auth__aside h1", text: /Cuéntanos qué\s*necesitas fabricar/
    assert_select "[data-controller=clerk][data-clerk-component-value=sign-up]"
  end

  test "con sesión iniciada lleva al inicio" do
    sign_in_as client_user(ClientCompany.create!(name: "Aromas del Valle"))

    get sign_in_path
    assert_redirected_to dashboard_path
  end
end
