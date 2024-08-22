package common

import "fmt"

type ExtraInstanceForClusterizationError struct {
	InstanceName string
}

func NewExtraInstanceForClusterizationError(instanceName string) *ExtraInstanceForClusterizationError {
	return &ExtraInstanceForClusterizationError{InstanceName: instanceName}
}

func (e *ExtraInstanceForClusterizationError) Error() string {
	return fmt.Sprintf("extra instance for clusterization: %s", e.InstanceName)
}
