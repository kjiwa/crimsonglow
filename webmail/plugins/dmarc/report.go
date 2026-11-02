package dmarc

import (
	"archive/zip"
	"bytes"
	"compress/gzip"
	"encoding/xml"
	"errors"
	"io"
	"mime"
	"sort"
	"strings"
	"time"

	"github.com/emersion/go-message"
)

const (
	maxAttachmentBytes = 5 << 20
	maxXMLBytes        = 10 << 20
	windowDays         = 30
)

var errTooLarge = errors.New("dmarc: attachment too large")

// Report is one RFC 7489 aggregate report.
type Report struct {
	Org     string
	ID      string
	Domain  string
	Policy  string
	Begin   time.Time
	End     time.Time
	Records []Record
}

// Record is one source row of a report.
type Record struct {
	IP          string
	Count       int
	Disposition string
	DKIM        string
	SPF         string
}

func (r Record) passed() bool { return r.DKIM == "pass" || r.SPF == "pass" }

type feedback struct {
	XMLName  xml.Name `xml:"feedback"`
	Metadata struct {
		Org   string `xml:"org_name"`
		ID    string `xml:"report_id"`
		Range struct {
			Begin int64 `xml:"begin"`
			End   int64 `xml:"end"`
		} `xml:"date_range"`
	} `xml:"report_metadata"`
	Policy struct {
		Domain string `xml:"domain"`
		P      string `xml:"p"`
	} `xml:"policy_published"`
	Records []struct {
		Row struct {
			IP        string `xml:"source_ip"`
			Count     int    `xml:"count"`
			Evaluated struct {
				Disposition string `xml:"disposition"`
				DKIM        string `xml:"dkim"`
				SPF         string `xml:"spf"`
			} `xml:"policy_evaluated"`
		} `xml:"row"`
	} `xml:"record"`
}

func parseReport(data []byte) (Report, error) {
	var f feedback
	if err := xml.Unmarshal(data, &f); err != nil {
		return Report{}, err
	}
	r := Report{
		Org:    f.Metadata.Org,
		ID:     f.Metadata.ID,
		Domain: f.Policy.Domain,
		Policy: f.Policy.P,
		Begin:  time.Unix(f.Metadata.Range.Begin, 0).UTC(),
		End:    time.Unix(f.Metadata.Range.End, 0).UTC(),
	}
	for _, rec := range f.Records {
		e := rec.Row.Evaluated
		r.Records = append(r.Records, Record{
			IP: rec.Row.IP, Count: rec.Row.Count,
			Disposition: e.Disposition, DKIM: e.DKIM, SPF: e.SPF,
		})
	}
	return r, nil
}

func readLimited(r io.Reader, limit int64) ([]byte, error) {
	data, err := io.ReadAll(io.LimitReader(r, limit+1))
	if err != nil {
		return nil, err
	}
	if int64(len(data)) > limit {
		return nil, errTooLarge
	}
	return data, nil
}

func unzipXML(data []byte) ([]byte, error) {
	zr, err := zip.NewReader(bytes.NewReader(data), int64(len(data)))
	if err != nil {
		return nil, err
	}
	for _, f := range zr.File {
		if !strings.HasSuffix(strings.ToLower(f.Name), ".xml") {
			continue
		}
		rc, err := f.Open()
		if err != nil {
			return nil, err
		}
		defer rc.Close()
		return readLimited(rc, maxXMLBytes)
	}
	return nil, errors.New("dmarc: no xml in zip")
}

func gunzip(data []byte) ([]byte, error) {
	zr, err := gzip.NewReader(bytes.NewReader(data))
	if err != nil {
		return nil, err
	}
	defer zr.Close()
	return readLimited(zr, maxXMLBytes)
}

func decodeAttachment(r io.Reader) (Report, error) {
	data, err := readLimited(r, maxAttachmentBytes)
	if err != nil {
		return Report{}, err
	}
	switch {
	case bytes.HasPrefix(data, []byte{0x1f, 0x8b}):
		data, err = gunzip(data)
	case bytes.HasPrefix(data, []byte("PK")):
		data, err = unzipXML(data)
	}
	if err != nil {
		return Report{}, err
	}
	return parseReport(data)
}

func isAttachment(e *message.Entity) bool {
	ctype, params, _ := e.Header.ContentType()
	_, disp, _ := mime.ParseMediaType(e.Header.Get("Content-Disposition"))
	name := strings.ToLower(params["name"] + disp["filename"])
	for _, suffix := range []string{".xml", ".gz", ".zip"} {
		if strings.HasSuffix(name, suffix) {
			return true
		}
	}
	switch ctype {
	case "text/xml", "application/xml", "application/gzip", "application/x-gzip",
		"application/zip", "application/x-zip-compressed":
		return true
	}
	return false
}

func walk(e *message.Entity, reports *[]Report, skipped *int) {
	if mr := e.MultipartReader(); mr != nil {
		for {
			part, err := mr.NextPart()
			if err != nil {
				if err != io.EOF && !message.IsUnknownCharset(err) {
					*skipped++
				}
				return
			}
			walk(part, reports, skipped)
		}
	}
	if !isAttachment(e) {
		return
	}
	r, err := decodeAttachment(e.Body)
	if err != nil {
		*skipped++
		return
	}
	*reports = append(*reports, r)
}

// decodeMessage returns the reports a raw message carries and 1 when it
// carries none that can be read.
func decodeMessage(raw []byte) ([]Report, int) {
	e, err := message.Read(bytes.NewReader(raw))
	if err != nil && !message.IsUnknownCharset(err) {
		return nil, 1
	}
	var reports []Report
	var skipped int
	walk(e, &reports, &skipped)
	if len(reports) == 0 && skipped == 0 {
		skipped = 1
	}
	return reports, skipped
}

// ReportRow is one report in the response.
type ReportRow struct {
	Org      string    `json:"org"`
	ID       string    `json:"id"`
	Domain   string    `json:"domain"`
	Policy   string    `json:"policy"`
	Begin    time.Time `json:"begin"`
	End      time.Time `json:"end"`
	Messages int       `json:"messages"`
	Passed   int       `json:"passed"`
}

// Source aggregates every record from one sending IP.
type Source struct {
	IP           string         `json:"ip"`
	Orgs         []string       `json:"orgs"`
	Messages     int            `json:"messages"`
	DKIM         int            `json:"dkim"`
	SPF          int            `json:"spf"`
	DMARC        int            `json:"dmarc"`
	Dispositions map[string]int `json:"dispositions"`
}

type Totals struct {
	Messages int `json:"messages"`
	DKIM     int `json:"dkim"`
	SPF      int `json:"spf"`
	DMARC    int `json:"dmarc"`
	Failed   int `json:"failed"`
}

// Verdict state is "empty", "ready" or "failing".
type Verdict struct {
	State          string `json:"state"`
	FailedMessages int    `json:"failedMessages"`
	FailedSources  int    `json:"failedSources"`
}

type Summary struct {
	Days    int         `json:"days"`
	Reports []ReportRow `json:"reports"`
	Sources []Source    `json:"sources"`
	Totals  Totals      `json:"totals"`
	Skipped int         `json:"skipped"`
	Verdict Verdict     `json:"verdict"`
}

func addRecord(s *Source, org string, rec Record) {
	s.Messages += rec.Count
	s.Dispositions[rec.Disposition] += rec.Count
	if rec.DKIM == "pass" {
		s.DKIM += rec.Count
	}
	if rec.SPF == "pass" {
		s.SPF += rec.Count
	}
	if rec.passed() {
		s.DMARC += rec.Count
	}
	for _, o := range s.Orgs {
		if o == org {
			return
		}
	}
	s.Orgs = append(s.Orgs, org)
}

func summarize(reports []Report, skipped int, now time.Time) Summary {
	s := Summary{Days: windowDays, Reports: []ReportRow{}, Sources: []Source{}, Skipped: skipped}
	cutoff := now.AddDate(0, 0, -windowDays)
	bySource := map[string]*Source{}

	for _, r := range reports {
		if r.End.Before(cutoff) {
			continue
		}
		row := ReportRow{Org: r.Org, ID: r.ID, Domain: r.Domain, Policy: r.Policy, Begin: r.Begin, End: r.End}
		for _, rec := range r.Records {
			src := bySource[rec.IP]
			if src == nil {
				src = &Source{IP: rec.IP, Orgs: []string{}, Dispositions: map[string]int{}}
				bySource[rec.IP] = src
			}
			addRecord(src, r.Org, rec)
			row.Messages += rec.Count
			if rec.passed() {
				row.Passed += rec.Count
			}
		}
		s.Reports = append(s.Reports, row)
	}

	for _, src := range bySource {
		sort.Strings(src.Orgs)
		s.Totals.Messages += src.Messages
		s.Totals.DKIM += src.DKIM
		s.Totals.SPF += src.SPF
		s.Totals.DMARC += src.DMARC
		if src.DMARC < src.Messages {
			s.Verdict.FailedSources++
		}
		s.Sources = append(s.Sources, *src)
	}
	s.Totals.Failed = s.Totals.Messages - s.Totals.DMARC
	s.Verdict.FailedMessages = s.Totals.Failed

	sort.Slice(s.Reports, func(i, j int) bool { return s.Reports[i].End.After(s.Reports[j].End) })
	sort.Slice(s.Sources, func(i, j int) bool {
		a, b := s.Sources[i], s.Sources[j]
		if a.Messages != b.Messages {
			return a.Messages > b.Messages
		}
		return a.IP < b.IP
	})

	switch {
	case s.Totals.Messages == 0:
		s.Verdict.State = "empty"
	case s.Totals.Failed == 0:
		s.Verdict.State = "ready"
	default:
		s.Verdict.State = "failing"
	}
	return s
}
