package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"github.com/aws/aws-sdk-go-v2/service/configservice/types"
	"log"
	"strings"
	"sync"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/configservice"
)

// Config holds the configuration parameters
type Config struct {
	ResourceTypes []string
	WorkerCount   int
}

// QueryProvider defines the interface for running queries
type QueryProvider interface {
	Run(ctx context.Context, config Config) error
	onBaseConfigurationItem(handler func(item types.BaseConfigurationItem) error)
}

// AwsResourceDiscoveryQuery implements the QueryProvider interface
type AwsResourceDiscoveryQuery struct {
	Cfg        aws.Config
	HandleItem func(item types.BaseConfigurationItem) error
}

// NewAwsResourceDiscoveryQuery creates a new instance of AwsResourceDiscoveryQuery
func NewAwsResourceDiscoveryQuery(ctx context.Context) (*AwsResourceDiscoveryQuery, error) {
	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		return nil, fmt.Errorf("unable to load SDK config, %v", err)
	}
	return &AwsResourceDiscoveryQuery{Cfg: cfg}, nil
}

// onBaseConfigurationItem sets the handler function for BaseConfigurationItem
func (q *AwsResourceDiscoveryQuery) onBaseConfigurationItem(handler func(item types.BaseConfigurationItem) error) {
	q.HandleItem = handler
}

// Run executes the resource discovery queries
func (q *AwsResourceDiscoveryQuery) Run(ctx context.Context, config Config) error {
	var wg sync.WaitGroup
	resourceChan := make(chan string, config.WorkerCount)

	for i := 0; i < config.WorkerCount; i++ {
		wg.Add(1)
		go q.worker(ctx, resourceChan, &wg)
	}

	for _, resourceType := range config.ResourceTypes {
		resourceChan <- resourceType
	}
	close(resourceChan)
	wg.Wait()
	log.Printf("Processing completed.", errors.New(""))
	return nil
}

func (q *AwsResourceDiscoveryQuery) worker(ctx context.Context, resourceChan chan string, wg *sync.WaitGroup) {
	defer wg.Done()
	for resourceType := range resourceChan {
		q.processResourceType(ctx, resourceType)
	}
}

func (q *AwsResourceDiscoveryQuery) getResourceIDs(ctx context.Context, resourceType string) ([]string, error) {
	client := configservice.NewFromConfig(q.Cfg)
	input := &configservice.ListDiscoveredResourcesInput{
		ResourceType: types.ResourceType(resourceType),
	}

	var resourceIDs []string
	paginator := configservice.NewListDiscoveredResourcesPaginator(client, input)
	for paginator.HasMorePages() {
		page, err := paginator.NextPage(ctx)
		if err != nil {
			return nil, err
		}
		for _, resource := range page.ResourceIdentifiers {
			resourceIDs = append(resourceIDs, *resource.ResourceId)
		}
	}
	return resourceIDs, nil
}

func (q *AwsResourceDiscoveryQuery) getBatchConfig(ctx context.Context, resourceType string, resourceIDs []string) error {
	client := configservice.NewFromConfig(q.Cfg)
	var validResourceIDs []string
	for _, id := range resourceIDs {
		if id != "" {
			validResourceIDs = append(validResourceIDs, id)
		}
	}

	if len(validResourceIDs) == 0 {
		log.Printf("No valid resources found for %s\n", resourceType)
		return nil
	}

	var resourceKeys []types.ResourceKey
	for _, id := range validResourceIDs {
		resourceKeys = append(resourceKeys, types.ResourceKey{ResourceType: types.ResourceType(resourceType), ResourceId: &id})
	}

	input := &configservice.BatchGetResourceConfigInput{
		ResourceKeys: resourceKeys,
	}
	log.Printf("Fetching config for %s with resource keys: %+v\n", resourceType, resourceKeys, errors.New(""))

	resp, err := client.BatchGetResourceConfig(ctx, input)
	if err != nil {
		log.Printf("Error fetching config for %s with resource keys: %+v\n", resourceType, resourceKeys)
		return err
	}

	for _, item := range resp.BaseConfigurationItems {
		if q.HandleItem != nil {
			err := q.HandleItem(item)
			if err != nil {
				log.Printf("Error handling item for %s: %v\n", resourceType, err)
			}
		} else {
			log.Printf("No handler set for BaseConfigurationItem")
		}
	}
	return nil
}

func (q *AwsResourceDiscoveryQuery) processResourceType(ctx context.Context, resourceType string) {
	resourceIDs, err := q.getResourceIDs(ctx, resourceType)
	if err != nil {
		log.Printf("Error getting resource IDs for %s: %v\n", resourceType, err)
		return
	}

	if len(resourceIDs) == 0 {
		log.Printf("No resources found for %s\n", resourceType)
		return
	}

	log.Printf("Processing %s with resource IDs: %s\n", resourceType, strings.Join(resourceIDs, ", "))

	batchSize := 20
	for i := 0; i < len(resourceIDs); i += batchSize {
		end := i + batchSize
		if end > len(resourceIDs) {
			end = len(resourceIDs)
		}
		err := q.getBatchConfig(ctx, resourceType, resourceIDs[i:end])
		if err != nil {
			log.Printf("Error processing batch for %s: %v\n", resourceType, err)
		}
	}
}

var SupportedResourceTypes = []string{
	"AWS::AppStream::DirectoryConfig",
	"AWS::AppStream::Application",
	"AWS::AppStream::Stack",
	"AWS::AppStream::Fleet",
	"AWS::AppFlow::Flow",
	"AWS::AppIntegrations::EventIntegration",
	"AWS::ApiGateway::Stage",
	"AWS::ApiGateway::RestApi",
	"AWS::ApiGatewayV2::Stage",
	"AWS::ApiGatewayV2::Api",
	"AWS::Athena::WorkGroup",
	"AWS::Athena::DataCatalog",
	"AWS::Athena::PreparedStatement",
	"AWS::CloudFront::Distribution",
	"AWS::CloudFront::StreamingDistribution",
	"AWS::CloudWatch::Alarm",
	"AWS::CloudWatch::MetricStream",
	"AWS::Logs::Destination",
	"AWS::RUM::AppMonitor",
	"AWS::Evidently::Project",
	"AWS::Evidently::Launch",
	"AWS::Evidently::Segment",
	"AWS::CodeGuruReviewer::RepositoryAssociation",
	"AWS::CodeGuruProfiler::ProfilingGroup",
	"AWS::Cognito::UserPool",
	"AWS::Cognito::UserPoolClient",
	"AWS::Cognito::UserPoolGroup",
	"AWS::Connect::PhoneNumber",
	"AWS::Connect::QuickConnect",
	"AWS::Connect::Instance",
	"AWS::CustomerProfiles::Domain",
	"AWS::CustomerProfiles::ObjectType",
	"AWS::Detective::Graph",
	"AWS::DynamoDB::Table",
	"AWS::EC2::Host",
	"AWS::EC2::EIP",
	"AWS::EC2::Instance",
	"AWS::EC2::NetworkInterface",
	"AWS::EC2::SecurityGroup",
	"AWS::EC2::NatGateway",
	"AWS::EC2::EgressOnlyInternetGateway",
	"AWS::EC2::EC2Fleet",
	"AWS::EC2::SpotFleet",
	"AWS::EC2::PrefixList",
	"AWS::EC2::FlowLog",
	"AWS::EC2::TransitGateway",
	"AWS::EC2::TransitGatewayAttachment",
	"AWS::EC2::TransitGatewayRouteTable",
	"AWS::EC2::VPCEndpoint",
	"AWS::EC2::VPCEndpointService",
	"AWS::EC2::VPCPeeringConnection",
	"AWS::EC2::RegisteredHAInstance",
	"AWS::EC2::SubnetRouteTableAssociation",
	"AWS::EC2::LaunchTemplate",
	"AWS::EC2::NetworkInsightsAccessScopeAnalysis",
	"AWS::EC2::TrafficMirrorTarget",
	"AWS::EC2::TrafficMirrorSession",
	"AWS::EC2::DHCPOptions",
	"AWS::EC2::IPAM",
	"AWS::EC2::NetworkInsightsPath",
	"AWS::EC2::TrafficMirrorFilter",
	"AWS::EC2::CapacityReservation",
	"AWS::EC2::ClientVpnEndpoint",
	"AWS::EC2::CustomerGateway",
	"AWS::EC2::InternetGateway",
	"AWS::EC2::NetworkAcl",
	"AWS::EC2::RouteTable",
	"AWS::EC2::Subnet",
	"AWS::EC2::VPC",
	"AWS::EC2::VPNConnection",
	"AWS::EC2::VPNGateway",
	"AWS::EC2::IPAMScope",
	"AWS::EC2::CarrierGateway",
	"AWS::EC2::TransitGatewayConnect",
	"AWS::EC2::IPAMPool",
	"AWS::EC2::TransitGatewayMulticastDomain",
	"AWS::EC2::NetworkInsightsAccessScope",
	"AWS::EC2::NetworkInsightsAnalysis",
	"AWS::EC2::Volume",
	"AWS::ImageBuilder::ImagePipeline",
	"AWS::ImageBuilder::DistributionConfiguration",
	"AWS::ImageBuilder::ContainerRecipe",
	"AWS::ImageBuilder::InfrastructureConfiguration",
	"AWS::ImageBuilder::ImageRecipe",
	"AWS::ECR::Repository",
	"AWS::ECR::RegistryPolicy",
	"AWS::ECR::PullThroughCacheRule",
	"AWS::ECR::PublicRepository",
	"AWS::ECS::Cluster",
	"AWS::ECS::TaskDefinition",
	"AWS::ECS::Service",
	"AWS::ECS::TaskSet",
	"AWS::ECS::CapacityProvider",
	"AWS::EFS::FileSystem",
	"AWS::EFS::AccessPoint",
	"AWS::EKS::Cluster",
	"AWS::EKS::FargateProfile",
	"AWS::EKS::IdentityProviderConfig",
	"AWS::EKS::Addon",
	"AWS::EMR::SecurityConfiguration",
	"AWS::Events::EventBus",
	"AWS::Events::ApiDestination",
	"AWS::Events::Archive",
	"AWS::Events::Endpoint",
	"AWS::Events::Connection",
	"AWS::Events::Rule",
	"AWS::EventSchemas::RegistryPolicy",
	"AWS::EventSchemas::Discoverer",
	"AWS::EventSchemas::Schema",
	"AWS::Forecast::Dataset",
	"AWS::Forecast::DatasetGroup",
	"AWS::FraudDetector::Label",
	"AWS::FraudDetector::EntityType",
	"AWS::FraudDetector::Variable",
	"AWS::FraudDetector::Outcome",
	"AWS::GuardDuty::Detector",
	"AWS::GuardDuty::ThreatIntelSet",
	"AWS::GuardDuty::IPSet",
	"AWS::GuardDuty::Filter",
	"AWS::InspectorV2::Filter",
	"AWS::IVS::Channel",
	"AWS::IVS::RecordingConfiguration",
	"AWS::IVS::PlaybackKeyPair",
	"AWS::Cassandra::Keyspace",
	"AWS::Elasticsearch::Domain",
	"AWS::OpenSearch::Domain",
	"AWS::OpenSearch::Domain",
	"AWS::Elasticsearch::Domain",
	"AWS::Personalize::Dataset",
	"AWS::Personalize::Schema",
	"AWS::Personalize::Solution",
	"AWS::Personalize::DatasetGroup",
	"AWS::Pinpoint::ApplicationSettings",
	"AWS::Pinpoint::Segment",
	"AWS::Pinpoint::App",
	"AWS::Pinpoint::Campaign",
	"AWS::Pinpoint::InAppTemplate",
	"AWS::Pinpoint::EmailChannel",
	"AWS::Pinpoint::EmailTemplate",
	"AWS::Pinpoint::EventStream",
	"AWS::QLDB::Ledger",
	"AWS::Kendra::Index",
	"AWS::Kinesis::Stream",
	"AWS::Kinesis::StreamConsumer",
	"AWS::KinesisAnalyticsV2::Application",
	"AWS::KinesisFirehose::DeliveryStream",
	"AWS::KinesisVideo::SignalingChannel",
	"AWS::KinesisVideo::Stream",
	"AWS::Lex::BotAlias",
	"AWS::Lex::Bot",
	"AWS::Lightsail::Disk",
	"AWS::Lightsail::Certificate",
	"AWS::Lightsail::Bucket",
	"AWS::Lightsail::StaticIp",
	"AWS::LookoutMetrics::Alert",
	"AWS::LookoutVision::Project",
	"AWS::Grafana::Workspace",
	"AWS::APS::RuleGroupsNamespace",
	"AWS::MemoryDB::SubnetGroup",
	"AWS::AmazonMQ::Broker",
	"AWS::MSK::Cluster",
	"AWS::MSK::Configuration",
	"AWS::MSK::BatchScramSecret",
	"AWS::MSK::ClusterPolicy",
	"AWS::MSK::VpcConnection",
	"AWS::KafkaConnect::Connector",
	"AWS::Redshift::Cluster",
	"AWS::Redshift::ClusterParameterGroup",
	"AWS::Redshift::ClusterSecurityGroup",
	"AWS::Redshift::ScheduledAction",
	"AWS::Redshift::ClusterSnapshot",
	"AWS::Redshift::ClusterSubnetGroup",
	"AWS::Redshift::EventSubscription",
	"AWS::Redshift::EndpointAccess",
	"AWS::Redshift::EndpointAuthorization",
	"AWS::RDS::DBInstance",
	"AWS::RDS::DBSecurityGroup",
	"AWS::RDS::DBSnapshot",
	"AWS::RDS::DBSubnetGroup",
	"AWS::RDS::EventSubscription",
	"AWS::RDS::DBCluster",
	"AWS::RDS::DBClusterSnapshot",
	"AWS::RDS::GlobalCluster",
	"AWS::RDS::OptionGroup",
	"AWS::Route53::HostedZone",
	"AWS::Route53::HealthCheck",
	"AWS::Route53Resolver::ResolverEndpoint",
	"AWS::Route53Resolver::ResolverRule",
	"AWS::Route53Resolver::ResolverRuleAssociation",
	"AWS::Route53Resolver::FirewallDomainList",
	"AWS::Route53Resolver::FirewallRuleGroupAssociation",
	"AWS::Route53Resolver::ResolverQueryLoggingConfig",
	"AWS::Route53Resolver::ResolverQueryLoggingConfigAssociation",
	"AWS::Route53Resolver::FirewallRuleGroup",
	"AWS::Route53RecoveryReadiness::Cell",
	"AWS::Route53RecoveryReadiness::ReadinessCheck",
	"AWS::Route53RecoveryReadiness::RecoveryGroup",
	"AWS::Route53RecoveryControl::Cluster",
	"AWS::Route53RecoveryControl::ControlPanel",
	"AWS::Route53RecoveryControl::RoutingControl",
	"AWS::Route53RecoveryControl::SafetyRule",
	"AWS::Route53RecoveryReadiness::ResourceSet",
	"AWS::SageMaker::CodeRepository",
	"AWS::SageMaker::Domain",
	"AWS::SageMaker::AppImageConfig",
	"AWS::SageMaker::Image",
	"AWS::SageMaker::Model",
	"AWS::SageMaker::NotebookInstance",
	"AWS::SageMaker::NotebookInstanceLifecycleConfig",
	"AWS::SageMaker::EndpointConfig",
	"AWS::SageMaker::Workteam",
	"AWS::SageMaker::FeatureGroup",
	"AWS::SES::ConfigurationSet",
	"AWS::SES::ContactList",
	"AWS::SES::Template",
	"AWS::SES::ReceiptFilter",
	"AWS::SES::ReceiptRuleSet",
	"AWS::SNS::Topic",
	"AWS::SQS::Queue",
	"AWS::S3::Bucket",
	"AWS::S3::AccountPublicAccessBlock",
	"AWS::S3::MultiRegionAccessPoint",
	"AWS::S3::StorageLens",
	"AWS::S3::AccessPoint",
	"AWS::WorkSpaces::ConnectionAlias",
	"AWS::WorkSpaces::Workspace",
	"AWS::Amplify::App",
	"AWS::Amplify::Branch",
	"AWS::AppConfig::Application",
	"AWS::AppConfig::Environment",
	"AWS::AppConfig::ConfigurationProfile",
	"AWS::AppConfig::DeploymentStrategy",
	"AWS::AppConfig::HostedConfigurationVersion",
	"AWS::AppConfig::ExtensionAssociation",
	"AWS::AppRunner::VpcConnector",
	"AWS::AppRunner::Service",
	"AWS::AppMesh::VirtualNode",
	"AWS::AppMesh::VirtualService",
	"AWS::AppMesh::VirtualGateway",
	"AWS::AppMesh::VirtualRouter",
	"AWS::AppMesh::Route",
	"AWS::AppMesh::GatewayRoute",
	"AWS::AppMesh::Mesh",
	"AWS::AppSync::GraphQLApi",
	"AWS::AuditManager::Assessment",
	"AWS::AutoScaling::AutoScalingGroup",
	"AWS::AutoScaling::LaunchConfiguration",
	"AWS::AutoScaling::ScalingPolicy",
	"AWS::AutoScaling::ScheduledAction",
	"AWS::AutoScaling::WarmPool",
	"AWS::Backup::BackupPlan",
	"AWS::Backup::BackupSelection",
	"AWS::Backup::BackupVault",
	"AWS::Backup::RecoveryPoint",
	"AWS::Backup::ReportPlan",
	"AWS::Backup::BackupPlan",
	"AWS::Backup::BackupSelection",
	"AWS::Backup::BackupVault",
	"AWS::Backup::RecoveryPoint",
	"AWS::Batch::JobQueue",
	"AWS::Batch::ComputeEnvironment",
	"AWS::Batch::SchedulingPolicy",
	"AWS::Budgets::BudgetsAction",
	"AWS::ACM::Certificate",
	"AWS::CloudFormation::Stack",
	"AWS::CloudTrail::Trail",
	"AWS::Cloud9::EnvironmentEC2",
	"AWS::ServiceDiscovery::Service",
	"AWS::ServiceDiscovery::PublicDnsNamespace",
	"AWS::ServiceDiscovery::HttpNamespace",
	"AWS::ServiceDiscovery::Instance",
	"AWS::CodeArtifact::Repository",
	"AWS::CodeBuild::Project",
	"AWS::CodeBuild::ReportGroup",
	"AWS::CodeDeploy::Application",
	"AWS::CodeDeploy::DeploymentConfig",
	"AWS::CodeDeploy::DeploymentGroup",
	"AWS::CodePipeline::Pipeline",
	"AWS::Config::ResourceCompliance",
	"AWS::Config::ConformancePackCompliance",
	"AWS::Config::ConfigurationRecorder",
	"AWS::Config::ResourceCompliance",
	"AWS::Config::ResourceCompliance",
	"AWS::Config::ConfigurationRecorder",
	"AWS::Config::ConformancePackCompliance",
	"AWS::Config::ConfigurationRecorder",
	"AWS::DMS::EventSubscription",
	"AWS::DMS::ReplicationSubnetGroup",
	"AWS::DMS::ReplicationInstance",
	"AWS::DMS::ReplicationTask",
	"AWS::DMS::Certificate",
	"AWS::DMS::Endpoint",
	"AWS::DataSync::LocationSMB",
	"AWS::DataSync::LocationFSxLustre",
	"AWS::DataSync::LocationFSxWindows",
	"AWS::DataSync::LocationS3",
	"AWS::DataSync::LocationEFS",
	"AWS::DataSync::LocationNFS",
	"AWS::DataSync::LocationHDFS",
	"AWS::DataSync::LocationObjectStorage",
	"AWS::DataSync::Task",
	"AWS::DeviceFarm::TestGridProject",
	"AWS::DeviceFarm::InstanceProfile",
	"AWS::DeviceFarm::Project",
	"AWS::ElasticBeanstalk::Application",
	"AWS::ElasticBeanstalk::ApplicationVersion",
	"AWS::ElasticBeanstalk::Environment",
	"AWS::FIS::ExperimentTemplate",
	"AWS::GlobalAccelerator::Listener",
	"AWS::GlobalAccelerator::EndpointGroup",
	"AWS::GlobalAccelerator::Accelerator",
	"AWS::Glue::Job",
	"AWS::Glue::Classifier",
	"AWS::Glue::MLTransform",
	"AWS::GroundStation::Config",
	"AWS::GroundStation::MissionProfile",
	"AWS::GroundStation::DataflowEndpointGroup",
	"AWS::HealthLake::FHIRDatastore",
	"AWS::IAM::User",
	"AWS::IAM::Group",
	"AWS::IAM::Role",
	"AWS::IAM::Policy",
	"AWS::IAM::SAMLProvider",
	"AWS::IAM::ServerCertificate",
	"AWS::IAM::InstanceProfile",
	"AWS::IAM::OIDCProvider",
	"AWS::AccessAnalyzer::Analyzer",
	"AWS::IoT::Authorizer",
	"AWS::IoT::SecurityProfile",
	"AWS::IoT::RoleAlias",
	"AWS::IoT::Dimension",
	"AWS::IoT::Policy",
	"AWS::IoT::MitigationAction",
	"AWS::IoT::ScheduledAudit",
	"AWS::IoT::AccountAuditConfiguration",
	"AWS::IoTSiteWise::Gateway",
	"AWS::IoT::CustomMetric",
	"AWS::IoT::JobTemplate",
	"AWS::IoT::ProvisioningTemplate",
	"AWS::IoT::CACertificate",
	"AWS::IoTWireless::ServiceProfile",
	"AWS::IoTWireless::MulticastGroup",
	"AWS::IoTWireless::FuotaTask",
	"AWS::IoT::FleetMetric",
	"AWS::IoTAnalytics::Datastore",
	"AWS::IoTAnalytics::Dataset",
	"AWS::IoTAnalytics::Pipeline",
	"AWS::IoTAnalytics::Channel",
	"AWS::IoTEvents::Input",
	"AWS::IoTEvents::DetectorModel",
	"AWS::IoTEvents::AlarmModel",
	"AWS::IoTTwinMaker::Workspace",
	"AWS::IoTTwinMaker::Entity",
	"AWS::IoTTwinMaker::Scene",
	"AWS::IoTTwinMaker::SyncJob",
	"AWS::IoTSiteWise::Dashboard",
	"AWS::IoTSiteWise::Project",
	"AWS::IoTSiteWise::Portal",
	"AWS::IoTSiteWise::AssetModel",
	"AWS::GreengrassV2::ComponentVersion",
	"AWS::KMS::Key",
	"AWS::KMS::Alias",
	"AWS::Lambda::Function",
	"AWS::Lambda::Alias",
	"AWS::Lambda::CodeSigningConfig",
	"AWS::M2::Environment",
	"AWS::NetworkFirewall::Firewall",
	"AWS::NetworkFirewall::FirewallPolicy",
	"AWS::NetworkFirewall::RuleGroup",
	"AWS::NetworkFirewall::TLSInspectionConfiguration",
	"AWS::NetworkManager::TransitGatewayRegistration",
	"AWS::NetworkManager::Site",
	"AWS::NetworkManager::Device",
	"AWS::NetworkManager::Link",
	"AWS::NetworkManager::GlobalNetwork",
	"AWS::NetworkManager::CustomerGatewayAssociation",
	"AWS::NetworkManager::LinkAssociation",
	"AWS::NetworkManager::ConnectPeer",
	"AWS::Panorama::Package",
	"AWS::ACMPCA::CertificateAuthority",
	"AWS::ACMPCA::CertificateAuthorityActivation",
	"AWS::ResilienceHub::ResiliencyPolicy",
	"AWS::ResilienceHub::App",
	"AWS::ResourceExplorer2::Index",
	"AWS::RoboMaker::RobotApplicationVersion",
	"AWS::RoboMaker::RobotApplication",
	"AWS::RoboMaker::SimulationApplication",
	"AWS::Signer::SigningProfile",
	"AWS::SecretsManager::Secret",
	"AWS::ServiceCatalog::CloudFormationProduct",
	"AWS::ServiceCatalog::CloudFormationProvisionedProduct",
	"AWS::ServiceCatalog::Portfolio",
	"AWS::Shield::Protection",
	"AWS::ShieldRegional::Protection",
	"AWS::StepFunctions::Activity",
	"AWS::StepFunctions::StateMachine",
	"AWS::SSM::ManagedInstanceInventory",
	"AWS::SSM::PatchCompliance",
	"AWS::SSM::AssociationCompliance",
	"AWS::SSM::FileData",
	"AWS::SSM::Document",
	"AWS::Transfer::Agreement",
	"AWS::Transfer::Connector",
	"AWS::Transfer::Workflow",
	"AWS::Transfer::Certificate",
	"AWS::Transfer::Profile",
	"AWS::WAF::RateBasedRule",
	"AWS::WAF::Rule",
	"AWS::WAF::WebACL",
	"AWS::WAF::RuleGroup",
	"AWS::WAFRegional::RateBasedRule",
	"AWS::WAFRegional::Rule",
	"AWS::WAFRegional::WebACL",
	"AWS::WAFRegional::RuleGroup",
	"AWS::WAFv2::WebACL",
	"AWS::WAFv2::RuleGroup",
	"AWS::WAFv2::ManagedRuleSet",
	"AWS::WAFv2::IPSet",
	"AWS::WAFv2::RegexPatternSet",
	"AWS::XRay::EncryptionConfig",
	"AWS::ElasticLoadBalancingV2::LoadBalancer",
	"AWS::ElasticLoadBalancingV2::Listener",
	"AWS::ElasticLoadBalancing::LoadBalancer",
	"AWS::ElasticLoadBalancingV2::LoadBalancer",
	"AWS::MediaConnect::FlowEntitlement",
	"AWS::MediaConnect::FlowVpcInterface",
	"AWS::MediaConnect::FlowSource",
	"AWS::MediaPackage::PackagingGroup",
	"AWS::MediaPackage::PackagingConfiguration",
	"AWS::MediaTailor::PlaybackConfiguration",
}

func main() {
	var resourceTypes string
	var workerCount int
	flag.StringVar(&resourceTypes, "resourceTypes", strings.Join(SupportedResourceTypes, ","), "Comma separated list of resource types")
	flag.IntVar(&workerCount, "workerCount", 5, "Number of concurrent workers")
	flag.Parse()

	config := Config{
		ResourceTypes: strings.Split(resourceTypes, ","),
		WorkerCount:   workerCount,
	}

	ctx := context.Background()
	queryProvider, err := NewAwsResourceDiscoveryQuery(ctx)
	if err != nil {
		log.Fatalf("Failed to create AwsResourceDiscoveryQuery: %v", err)
	}

	handleItem := func(item types.BaseConfigurationItem) error {
		itemJSON, err := json.MarshalIndent(item, "", "  ")
		if err != nil {
			return fmt.Errorf("failed to marshal item to JSON: %w", err)
		}
		fmt.Println(string(itemJSON))
		return nil
	}

	queryProvider.onBaseConfigurationItem(handleItem)

	err = queryProvider.Run(ctx, config)
	if err != nil {
		log.Fatalf("Error running query: %v", err)
	}
}
