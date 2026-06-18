# frozen_string_literal: true

SOURCE_ROOT = ENV.fetch('ORAMBO_SOURCE_ROOT')
RESULT_PATH = ENV.fetch('ORAMBO_SMOKE_RESULT')

UI.start_timer(1.0, false) do
  results = []
  created = []
  begin
    load File.join(SOURCE_ROOT, 'orambo_face_tools', 'main.rb')
    model = Sketchup.active_model

    flatten_group = model.active_entities.add_group
    created << flatten_group
    points = [[0, 0, 0], [1000.mm, 0, 5.mm], [1000.mm, 1000.mm, -3.mm], [0, 1000.mm, 2.mm]]
    points.each_with_index { |point, index| flatten_group.entities.add_line(point, points[(index + 1) % points.length]) }
    flatten_context = { entities: flatten_group.entities, edges: flatten_group.entities.grep(Sketchup::Edge),
                        transform: flatten_group.transformation, container: flatten_group }
    flatten_report = ORAMBO::FaceTools::Report.new('Smoke Flatten')
    ORAMBO::FaceTools::FlattenEdgesToZ.flatten_context(flatten_context, 0.0, 0.001.mm.to_f, flatten_report)
    z_values = flatten_group.entities.grep(Sketchup::Edge).flat_map(&:vertices).uniq.map { |vertex| vertex.position.transform(flatten_group.transformation).z }
    results << "flatten=#{z_values.all? { |z| z.abs < 0.00001 } ? 'PASS' : 'FAIL'}"

    face_group = model.active_entities.add_group
    created << face_group
    face_points = [[0, 0, 0], [1000.mm, 0, 0], [1000.mm, 1000.mm, 0], [0, 1000.mm, 0]]
    face_points.each_with_index { |point, index| face_group.entities.add_line(point, face_points[(index + 1) % face_points.length]) }
    face_context = { entities: face_group.entities, edges: face_group.entities.grep(Sketchup::Edge),
                     transform: face_group.transformation, container: face_group }
    face_report = ORAMBO::FaceTools::Report.new('Smoke Make Faces')
    ORAMBO::FaceTools::MakeFaces.process_context(model, face_context, 0.0, 10, false, 'Вверх по Z', false, face_report)
    results << "make_faces=#{face_group.entities.grep(Sketchup::Face).length == 1 ? 'PASS' : 'FAIL'}"

    curve_group = model.active_entities.add_group
    created << curve_group
    curve_group.entities.add_arc(ORIGIN, X_AXIS, Y_AXIS, 500.mm, 0, Math::PI, 8)
    curve_report = ORAMBO::FaceTools::Report.new('Smoke Break')
    ORAMBO::FaceTools::BreakToSegments.convert_curves(curve_group.entities, nil, false, curve_report)
    curves_left = curve_group.entities.grep(Sketchup::Edge).map(&:curve).compact
    results << "break_curves=#{curves_left.empty? ? 'PASS' : 'FAIL'}"
  rescue Exception => error
    results << "error=#{error.class}: #{error.message}"
    results << error.backtrace.first(10).join(' | ')
  ensure
    created.each { |entity| entity.erase! if entity.valid? }
    File.open(RESULT_PATH, 'w:utf-8') { |file| file.write(results.join("\n")) }
    Sketchup.quit
  end
end
