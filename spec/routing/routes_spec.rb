describe 'routing', type: :routing do
  BAD_MATCH = %r{^/rails|^/assets|^/cable|.*\*path\(.:format\)}
  Rails.application.routes.routes.map do |r|
    spec = r.path.spec.to_s
    next if spec.match BAD_MATCH
    r.verb.split('|').each do |verb|
      it "#{verb}: #{r.path.spec}" do
        parts = r.required_parts.map { |part| [part, '1'] }.to_h
        path = r.path.build_formatter.evaluate(parts)
        expect(verb.downcase => path).to route_to(**r.defaults, **parts)
      end
    end
  end

  context 'Root with locale' do
    it 'routes /en/ to error' do
      expect(get: '/en/').to route_to(controller: 'main', action: 'page_not_found', path: 'en')
    end
  end
end
