package dmarc

import (
	"archive/zip"
	"bytes"
	"compress/gzip"
	"encoding/base64"
	"fmt"
	"os"
	"strings"
	"testing"
	"time"
)

var now = time.Unix(1790100000, 0)

func fixture(t *testing.T, name string) []byte {
	t.Helper()
	data, err := os.ReadFile("testdata/" + name)
	if err != nil {
		t.Fatal(err)
	}
	return data
}

func gz(t *testing.T, data []byte) []byte {
	t.Helper()
	var buf bytes.Buffer
	w := gzip.NewWriter(&buf)
	if _, err := w.Write(data); err != nil {
		t.Fatal(err)
	}
	if err := w.Close(); err != nil {
		t.Fatal(err)
	}
	return buf.Bytes()
}

func zipped(t *testing.T, name string, data []byte) []byte {
	t.Helper()
	var buf bytes.Buffer
	w := zip.NewWriter(&buf)
	f, err := w.Create(name)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := f.Write(data); err != nil {
		t.Fatal(err)
	}
	if err := w.Close(); err != nil {
		t.Fatal(err)
	}
	return buf.Bytes()
}

func mail(contentType, filename string, attachment []byte) []byte {
	return []byte(fmt.Sprintf("From: noreply@example.com\r\nSubject: Report Domain: crimsonglow.ca\r\n"+
		"MIME-Version: 1.0\r\nContent-Type: multipart/mixed; boundary=b\r\n\r\n"+
		"--b\r\nContent-Type: text/plain\r\n\r\nReport attached.\r\n"+
		"--b\r\nContent-Type: %s; name=%q\r\nContent-Disposition: attachment; filename=%q\r\n"+
		"Content-Transfer-Encoding: base64\r\n\r\n%s\r\n--b--\r\n",
		contentType, filename, filename, base64.StdEncoding.EncodeToString(attachment)))
}

func TestDecodeMessageFormats(t *testing.T) {
	xml := fixture(t, "google.xml")
	tests := []struct {
		name string
		raw  []byte
	}{
		{"plain xml", mail("text/xml", "google.com!crimsonglow.ca!1.xml", xml)},
		{"gzip", mail("application/gzip", "google.com!crimsonglow.ca!1.xml.gz", gz(t, xml))},
		{"zip", mail("application/zip", "google.com!crimsonglow.ca!1.zip", zipped(t, "r.xml", xml))},
		{"octet-stream named gz", mail("application/octet-stream", "r.xml.gz", gz(t, xml))},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			reports, skipped := decodeMessage(tt.raw)
			if skipped != 0 || len(reports) != 1 {
				t.Fatalf("got %d reports, %d skipped", len(reports), skipped)
			}
			r := reports[0]
			if r.Org != "google.com" || r.ID != "1001" || r.Domain != "crimsonglow.ca" || r.Policy != "none" {
				t.Errorf("metadata: %+v", r)
			}
			if r.End.Unix() != 1790086399 || len(r.Records) != 1 {
				t.Errorf("range or records: %+v", r)
			}
			rec := r.Records[0]
			if rec.IP != "203.0.113.10" || rec.Count != 4 || rec.Disposition != "none" || rec.DKIM != "pass" || rec.SPF != "pass" {
				t.Errorf("record: %+v", rec)
			}
		})
	}
}

func TestDecodeMessageSinglePartGzip(t *testing.T) {
	body := base64.StdEncoding.EncodeToString(gz(t, fixture(t, "google.xml")))
	raw := []byte("Subject: r\r\nContent-Type: application/gzip; name=\"r.xml.gz\"\r\n" +
		"Content-Transfer-Encoding: base64\r\n\r\n" + body + "\r\n")
	reports, skipped := decodeMessage(raw)
	if skipped != 0 || len(reports) != 1 {
		t.Fatalf("got %d reports, %d skipped", len(reports), skipped)
	}
}

func TestDecodeMessageMultiRecord(t *testing.T) {
	reports, skipped := decodeMessage(mail("text/xml", "m.xml", fixture(t, "multi.xml")))
	if skipped != 0 || len(reports) != 1 || len(reports[0].Records) != 2 {
		t.Fatalf("got %+v, %d skipped", reports, skipped)
	}
	if reports[0].Records[1].IP != "198.51.100.7" || reports[0].Records[1].Count != 3 {
		t.Errorf("second record: %+v", reports[0].Records[1])
	}
}

func TestDecodeMessageSkipsUnreadable(t *testing.T) {
	tests := map[string][]byte{
		"malformed xml":   mail("text/xml", "bad.xml", []byte("<feedback><record>")),
		"not a feedback":  mail("text/xml", "other.xml", []byte("<html></html>")),
		"corrupt gzip":    mail("application/gzip", "bad.xml.gz", []byte("\x1f\x8bnot gzip")),
		"zip without xml": mail("application/zip", "r.zip", zipped(t, "readme.txt", []byte("hi"))),
		"no attachment":   []byte("Subject: hello\r\nContent-Type: text/plain\r\n\r\nhi\r\n"),
		"not a message":   {},
	}
	for name, raw := range tests {
		t.Run(name, func(t *testing.T) {
			reports, skipped := decodeMessage(raw)
			if len(reports) != 0 || skipped != 1 {
				t.Fatalf("got %d reports, %d skipped", len(reports), skipped)
			}
		})
	}
}

func TestDecodeMessageBoundsDecompression(t *testing.T) {
	filler := strings.Repeat("<!-- x -->", maxXMLBytes/10+1)
	bomb := []byte("<feedback>" + filler + "</feedback>")
	if len(bomb) <= maxXMLBytes {
		t.Fatal("bomb is too small to test the limit")
	}
	for name, raw := range map[string][]byte{
		"gzip": mail("application/gzip", "b.xml.gz", gz(t, bomb)),
		"zip":  mail("application/zip", "b.zip", zipped(t, "b.xml", bomb)),
	} {
		t.Run(name, func(t *testing.T) {
			if len(raw) > maxAttachmentBytes {
				t.Fatalf("attachment %d bytes exceeds the compressed limit, test is not exercising decompression", len(raw))
			}
			reports, skipped := decodeMessage(raw)
			if len(reports) != 0 || skipped != 1 {
				t.Fatalf("got %d reports, %d skipped", len(reports), skipped)
			}
		})
	}
}

func TestDecodeMessageRejectsOversizedAttachment(t *testing.T) {
	big := bytes.Repeat([]byte{0x41}, maxAttachmentBytes+1)
	reports, skipped := decodeMessage(mail("application/gzip", "big.gz", big))
	if len(reports) != 0 || skipped != 1 {
		t.Fatalf("got %d reports, %d skipped", len(reports), skipped)
	}
}

func decodeFixtures(t *testing.T, names ...string) []Report {
	t.Helper()
	var all []Report
	for _, name := range names {
		reports, skipped := decodeMessage(mail("text/xml", name, fixture(t, name)))
		if skipped != 0 {
			t.Fatalf("%s skipped", name)
		}
		all = append(all, reports...)
	}
	return all
}

func TestSummarizeAggregatesAcrossReports(t *testing.T) {
	s := summarize(decodeFixtures(t, "google.xml", "multi.xml"), 0, now)

	if s.Totals != (Totals{Messages: 9, DKIM: 6, SPF: 4, DMARC: 6, Failed: 3}) {
		t.Errorf("totals: %+v", s.Totals)
	}
	if len(s.Reports) != 2 || s.Reports[0].Messages+s.Reports[1].Messages != 9 {
		t.Errorf("reports: %+v", s.Reports)
	}
	if len(s.Sources) != 2 {
		t.Fatalf("sources: %+v", s.Sources)
	}
	a := s.Sources[0]
	if a.IP != "203.0.113.10" || a.Messages != 6 || a.DKIM != 6 || a.SPF != 4 || a.DMARC != 6 {
		t.Errorf("first source: %+v", a)
	}
	if strings.Join(a.Orgs, ",") != "google.com,outlook.com" || a.Dispositions["none"] != 6 {
		t.Errorf("first source orgs or dispositions: %+v", a)
	}
	b := s.Sources[1]
	if b.IP != "198.51.100.7" || b.DMARC != 0 || b.Messages != 3 {
		t.Errorf("second source: %+v", b)
	}
	if s.Verdict != (Verdict{State: "failing", FailedMessages: 3, FailedSources: 1}) {
		t.Errorf("verdict: %+v", s.Verdict)
	}
}

func TestSummarizeReadyWhenEverythingPasses(t *testing.T) {
	s := summarize(decodeFixtures(t, "google.xml"), 0, now)
	if s.Verdict.State != "ready" || s.Totals.Failed != 0 {
		t.Errorf("verdict: %+v totals: %+v", s.Verdict, s.Totals)
	}
}

func TestSummarizeDropsReportsOlderThanThirtyDays(t *testing.T) {
	s := summarize(decodeFixtures(t, "google.xml", "old.xml"), 0, now)
	if len(s.Reports) != 1 || s.Totals.Messages != 4 {
		t.Errorf("reports: %+v totals: %+v", s.Reports, s.Totals)
	}
}

func TestSummarizeEmptyAndSkipped(t *testing.T) {
	s := summarize(nil, 2, now)
	if s.Verdict.State != "empty" || s.Skipped != 2 || s.Reports == nil || s.Sources == nil {
		t.Errorf("summary: %+v", s)
	}
}
