require "test_helper"

# Los archivos se piden por /archivos/:id, que revisa quién los pide y redirige a una URL firmada que vence.
class FileAccessTest < ActionDispatch::IntegrationTest
  setup do
    @sub_order = sub_order_in_inspection
    @company = @sub_order.order.client_company
    @requirement = @sub_order.order.requirement
    @requirement.files.attach(fixture_upload("plano.dxf", "application/dxf"))
    @design = @requirement.files.attachments.first
    @payment_support = @sub_order.payments.first.support.attachment
    @sample_photo = @sub_order.samples.first.photos.attachments.first
  end

  test "el equipo de KOVZU abre cualquier archivo con una URL que vence" do
    sign_in_as staff_user(role: "operador")

    get file_path(@payment_support)
    assert_response :redirect
    assert_match %r{/rails/active_storage/disk/}, response.location
    assert_equal "private, no-store", response.headers["Cache-Control"]

    get file_path(@design, disposition: "attachment")
    follow_redirect!
    assert_response :success
    assert_match(/\Aattachment; filename="plano.dxf"/, response.headers["Content-Disposition"])
  end

  test "sin sesión no se abre ningún archivo" do
    [ @design, @payment_support, @sample_photo ].each do |attachment|
      get file_path(attachment)
      assert_response :not_found
    end

    get "/rails/active_storage/blobs/redirect/#{@design.blob.signed_id}/plano.dxf"
    assert_response :not_found, "los enlaces permanentes de Active Storage ya no existen"
  end

  test "el cliente abre los archivos de su empresa, pero no los soportes internos ni los de otra empresa" do
    sign_in_as client_user(@company)

    get file_path(@design)
    assert_response :redirect
    get file_path(@sample_photo)
    assert_response :redirect
    get file_path(@payment_support)
    assert_response :not_found
    get file_path(@sub_order.quotes.first.support.attachment)
    assert_response :not_found

    sign_in_as client_user(ClientCompany.create!(name: "Otra marca"), email: "otro@marca.co")
    get file_path(@design)
    assert_response :not_found
    get file_path(@sample_photo)
    assert_response :not_found
  end

  test "el cliente ve las fotos de la inspección solo cuando el acta está cerrada" do
    inspection = fill_inspection(Inspection.start_for!(@sub_order, by: "Ana"), nonconforming: { "medidas" => "menor" })
    photo = inspection.items.find_by(key: "medidas").photos.attachments.first
    sign_in_as client_user(@company)

    get file_path(photo)
    assert_response :not_found

    inspection.close!(result: "rechazado", rework_due_on: Date.current + 7, user: staff_user)
    get file_path(photo)
    assert_response :redirect
  end

  test "el taller abre los archivos del requerimiento con el token de su enlace y nada más" do
    sub_order = start_order.sub_orders.first
    ready_sheet!(sub_order)
    requirement = sub_order.order.requirement
    requirement.files.attach(fixture_upload("plano.dxf", "application/dxf"))
    design = requirement.files.attachments.first
    quote = sub_order.request_quotes!([ create_workshop("Cartón Valle", category: sub_order.category).id ], by: "Ana").first

    get workshop_quote_path(quote.token)
    assert_select "a[href=?]", file_path(design, disposition: "attachment", token: quote.token)

    get file_path(design, token: quote.token)
    assert_response :redirect
    get file_path(design, token: "otro-token")
    assert_response :not_found
    get file_path(@design, token: quote.token)
    assert_response :not_found, "un diseño de otro pedido"
    get file_path(@payment_support, token: quote.token)
    assert_response :not_found

    quote.update!(link_expires_at: 1.minute.ago)
    get file_path(design, token: quote.token)
    assert_response :not_found
  end
end
