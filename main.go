package main

import (
	"context"
	"fmt"
	"io/ioutil"
	"net/http"

	"github.com/EconomistDigitalSolutions/cp-utils/cpaws"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/service/sqs"
)

var (
	AwsRegion = "us-east-1"
	sqsQueue  = "https://sqs.us-east-1.amazonaws.com/680545668187/test_queue"
)

func main() {
	http.HandleFunc("/", handler)
	http.ListenAndServe(":9494", nil)
}

func handler(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()
	payload, err := ioutil.ReadAll(r.Body)
	if err != nil {
		fmt.Println(err.Error())
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte(`{"code":500,"message":"Internal Server Error"}`))
	}

	resp, err := sendSQSMessage(string(payload), ctx)
	if err != nil {
		fmt.Println(err.Error())
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte(`{"code":500,"message":"Internal Server Error"}`))
	}

	json := `{"code":200,"message":"` + resp + `"}`
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(json))
}

func sendSQSMessage(message string, ctx context.Context) (string, error) {
	awsSession, err := cpaws.GetSession(ctx)
	if err != nil {
		fmt.Println(err.Error())
		return resp.String(), err
	}
	svc := sqs.New(awsSession, aws.NewConfig().WithRegion(awsRegion))

	input := sqs.SendMessageInput{
		MessageBody: &message,
		QueueUrl:    &sqsQueue,
	}
	resp, err := svc.SendMessage(&input)
	if err != nil {
		fmt.Println(err.Error())
		return resp.String(), err
	}
	return resp.String(), nil
}
