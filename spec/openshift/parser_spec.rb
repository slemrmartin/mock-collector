describe TopologicalInventory::MockSource::Openshift::Parser do
  let(:server) { TopologicalInventory::MockSource::Openshift::Server.new }

  before do
    @amounts = {
      :service_offerings   => 1,
      :service_plans       => 1,
      :container_projects  => 1,
      :container_nodes     => 1,
      :container_groups    => 1,
      :service_instances   => 1,
      :container_templates => 1,
      :container_images    => 1
    }

    stub_settings_merge(:refresh_mode   => :full_refresh,
                        :multithreading => :off,
                        :amounts        => @amounts)

    @storage = TopologicalInventory::MockSource::Openshift::Storage.new(server)
    @storage.create_entities

    @parser = TopologicalInventory::MockSource::Openshift::Parser.new
  end

  it "parses openshift mock objects correctly" do
    container_project  = @storage.container_projects.get_entity(0)
    container_node     = @storage.container_nodes.get_entity(0)
    container_group    = @storage.container_groups.get_entity(0)
    container_image    = @storage.container_images.get_entity(0)
    container_template = @storage.container_templates.get_entity(0)
    service_instance   = @storage.service_instances.get_entity(0)
    service_offering   = @storage.service_offerings.get_entity(0)
    service_plan       = @storage.service_plans.get_entity(0)

    entity_types = @storage.class.entity_types

    @parser.parse_entity(:container_projects, container_project, entity_types[:container_projects])
    assert_container_project(container_project, @parser.collections[:container_projects].data.first)

    @parser.parse_entity(:container_nodes, container_node, entity_types[:container_nodes])
    assert_container_node(container_node, @parser.collections[:container_nodes].data.first)

    @parser.parse_entity(:container_groups, container_group, entity_types[:container_groups])
    assert_container_group(container_group, @parser.collections[:container_groups].data.first)
    assert_container(container_group, @parser.collections[:containers].data.first)

    @parser.parse_entity(:container_images, container_image, entity_types[:container_images])
    assert_container_image(container_image, @parser.collections[:container_images].data.first)

    @parser.parse_entity(:container_templates, container_template, entity_types[:container_templates])
    assert_container_template(container_template, @parser.collections[:container_templates].data.first)

    @parser.parse_entity(:service_instances, service_instance, entity_types[:service_instances])
    assert_service_instance(service_instance, @parser.collections[:service_instances].data.first)

    @parser.parse_entity(:service_offerings, service_offering, entity_types[:service_offerings])
    assert_service_offering(service_offering, @parser.collections[:service_offerings].data.first)

    @parser.parse_entity(:service_plans, service_plan, entity_types[:service_plans])
    assert_service_plan(service_plan, @parser.collections[:service_plans].data.first)
  end

  private

  def assert_container_project(mock_container_project, api_container_project)
    expect(api_container_project).to be_instance_of(::TopologicalInventoryIngressApiClient::ContainerProject)
    expect(api_container_project).to have_base_attributes(mock_container_project)
    expect(api_container_project).to have_attributes(
      :display_name => nil
    )

    assert_tag(:container_project_tags, :source_ref => mock_container_project.uid)
  end

  def assert_container_node(mock_container_node, api_container_node)
    expect(api_container_node).to be_instance_of(::TopologicalInventoryIngressApiClient::ContainerNode)
    expect(api_container_node).to have_base_attributes(mock_container_node)
    expect(api_container_node).to have_attributes(
      :cpus   => mock_container_node.data[:cpus],
      :memory => mock_container_node.data[:memory],
    )
    assert_lazy_object(api_container_node.lives_on, :uid_ems => nil)
    assert_tag(:container_node_tags, :source_ref => mock_container_node.uid)
  end

  def assert_container_group(mock_container_group, api_container_group)
    expect(api_container_group).to be_instance_of(::TopologicalInventoryIngressApiClient::ContainerGroup)
    expect(api_container_group).to have_base_attributes(mock_container_group)

    expect(api_container_group).to have_attributes(
      :ipaddress => mock_container_group.data[:ipaddress]
    )
    assert_lazy_object(api_container_group.container_node, :name => @storage.entities[:container_nodes].get_entity(0).data[:name])
    assert_lazy_object(api_container_group.container_project, :name => @storage.entities[:container_projects].get_entity(0).data[:name])

    assert_tag(:container_group_tags, :source_ref => mock_container_group.data[:source_ref])
  end

  # TODO (mslemr): write again, get original entity
  def assert_container(mock_container_group, api_container)
    return
    mock_container = @storage.entities[:containers].get_entity(mock_container_group.ref_id.to_i)
    expect(mock_container).not_to be_nil

    expect(api_container).to be_instance_of(::TopologicalInventoryIngressApiClient::Container)
    expect(api_container).to have_attributes(
      :name           => mock_container.data[:name],
      # :cpu_limit      => mock_container.data[:cpu_limit], #random values
      # :cpu_request    => mock_container.data[:cpu_request],
      # :memory_limit   => mock_container.data[:memory_limit],
      # :memory_request => mock_container.data[:memory_request]
    )

    assert_lazy_object(api_container.container_group, :source_ref => mock_container_group.data[:source_ref])
    assert_lazy_object(api_container.container_image, :source_ref => mock_container.container_image)
  end

  def assert_container_image(mock_container_image, api_container_image)
    expect(api_container_image).to be_instance_of(::TopologicalInventoryIngressApiClient::ContainerImage)

    expect(api_container_image).to have_attributes(
      :name              => mock_container_image.data[:name],
      :resource_version  => mock_container_image.data[:resource_version],
      :source_created_at => mock_container_image.data[:source_created_at],
      :source_deleted_at => mock_container_image.data[:source_deleted_at],
      :source_ref        => mock_container_image.data[:source_ref]
    )

    assert_tag(:container_image_tags, { :source_ref => mock_container_image.uid }, {:tags_count => 1})
  end

  def assert_container_template(mock_container_template, api_container_template)
    expect(api_container_template).to be_instance_of(::TopologicalInventoryIngressApiClient::ContainerTemplate)

    expect(api_container_template).to have_base_attributes(mock_container_template)

    assert_lazy_object(api_container_template.container_project, :name => mock_container_template.metadata.container_project)
    assert_tag(:container_template_tags, :source_ref => mock_container_template.uid)
  end

  def assert_service_instance(mock_service_instance, api_service_instance)
    expect(api_service_instance).to be_instance_of(::TopologicalInventoryIngressApiClient::ServiceInstance)

    expect(api_service_instance).to have_attributes(
      :name              => mock_service_instance.data[:name],
      :source_ref        => mock_service_instance.data[:source_ref],
      :source_created_at => mock_service_instance.data[:source_created_at],
      :source_region     => nil,
      :subscription      => nil
    )

    assert_lazy_object(api_service_instance.service_offering, :source_ref => mock_service_instance.spec.clusterServiceClassRef.name)
    assert_lazy_object(api_service_instance.service_plan, :source_ref => mock_service_instance.spec.clusterServicePlanRef.name)
  end

  def assert_service_offering(mock_cluster_svc_class, api_service_offering)
    expect(api_service_offering).to be_instance_of(TopologicalInventoryIngressApiClient::ServiceOffering)

    expect(api_service_offering).to have_attributes(
      :name              => mock_cluster_svc_class.data[:name],
      :source_ref        => mock_cluster_svc_class.data[:source_ref],
      :description       => mock_cluster_svc_class.data[:description],
      :display_name      => mock_cluster_svc_class.data[:display_name],
      :documentation_url => mock_cluster_svc_class.data[:documentation_url],
      :long_description  => mock_cluster_svc_class.data[:long_description],
      :distributor       => mock_cluster_svc_class.data[:distributor],
      :support_url       => mock_cluster_svc_class.data[:support_url],
      :source_created_at => mock_cluster_svc_class.data[:source_created_at],
      :source_region     => nil,
      :subscription      => nil,
    )

    assert_lazy_object(api_service_offering.service_offering_icon, :source_ref => nil)
  end

  def assert_service_plan(mock_cluster_svc_plan, api_service_plan)
    expect(api_service_plan).to be_instance_of(TopologicalInventoryIngressApiClient::ServicePlan)

    expect(api_service_plan).to have_attributes(
      :name               => mock_cluster_svc_plan.data[].externalName,
      :source_ref         => mock_cluster_svc_plan.data[:source_ref],
      :description        => mock_cluster_svc_plan.data[:description],
      :resource_version   => mock_cluster_svc_plan.data[:resource_version],
      :source_created_at  => mock_cluster_svc_plan.data[:source_created_at],
      :create_json_schema => mock_cluster_svc_plan.data[:create_json_schema],
      :update_json_schema => nil,
      :source_region      => nil,
      :subscription       => nil
    )

    assert_lazy_object(api_service_plan.service_offering, :source_ref => mock_cluster_svc_plan.spec.clusterServiceClassRef.name)
  end

  def assert_tag(tag_collection_name, reference, tags_count: 1)
    api_tag = @parser.collections[tag_collection_name].data.first

    assert_tags_common(tag_collection_name, :tags_count => tags_count)

    # skip suffix to get parent collection reference name
    key_name_to_parent = tag_collection_name.to_s.gsub("_tags", "").to_sym
    assert_lazy_object(api_tag.send(key_name_to_parent), reference)
  end

  # Helpers -------------

  def have_base_attributes(mock_entity)
    have_attributes(
      :name              => mock_entity.data[:name],
      :resource_version  => mock_entity.data[:resource_version],
      :source_created_at => mock_entity.data[:source_created_at],
      :source_deleted_at => mock_entity.data[:source_deleted_at],
      :source_ref        => mock_entity.data[:source_ref]
    )
  end

  def assert_tags_common(tag_collection_name, tags_count: 1)
    expect(@parser.collections[tag_collection_name].data.count).to eq(tags_count)

    # Tag class
    api_class_name = "TopologicalInventoryIngressApiClient::#{tag_collection_name.to_s.classify}"
    api_tag = @parser.collections[tag_collection_name].data[0]
    expect(api_tag.class.name).to eq(api_class_name)

    # Name/value
    assert_lazy_object(api_tag.tag, :name => "mock-tag-0", :value => "0")
  end

  def assert_lazy_object(lazy_object, reference)
    expect(lazy_object).not_to be_nil
    expect(lazy_object.reference).to eq(reference)
  end
end
