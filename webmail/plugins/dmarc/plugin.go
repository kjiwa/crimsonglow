package dmarc

import (
	"net/http"
	"time"

	"github.com/migadu/alps"
	"github.com/migadu/alps/provider"
)

const (
	folder       = "DMARC"
	pageSize     = 50
	maxMessages  = 200
	maxFetchSize = 8 << 20
)

func folderExists(p provider.MailProvider) (bool, error) {
	boxes, err := p.ListMailboxes()
	if err != nil {
		return false, err
	}
	for _, b := range boxes {
		if b.Name == folder {
			return true, nil
		}
	}
	return false, nil
}

// messageIDs lists the newest messages. A threaded listing returns one row per
// conversation and names its members in ThreadUIDs.
func messageIDs(p provider.MailProvider) ([]provider.MessageID, error) {
	var ids []provider.MessageID
	seen := map[string]bool{}
	add := func(id provider.MessageID) bool {
		if seen[id.String()] || len(ids) >= maxMessages {
			return false
		}
		seen[id.String()] = true
		ids = append(ids, id)
		return true
	}

	for page := 0; len(ids) < maxMessages; page++ {
		rows, _, err := p.ListMessages(folder, "desc", page, pageSize)
		if err != nil {
			return nil, err
		}
		added := false
		for _, row := range rows {
			if len(row.ThreadUIDs) == 0 {
				added = add(row.ID) || added
			}
			for _, uid := range row.ThreadUIDs {
				if id, err := p.ParseMessageID(uid); err == nil {
					added = add(id) || added
				}
			}
		}
		// A page past the end may come back empty or repeat the last one.
		if !added {
			break
		}
	}
	return ids, nil
}

func collect(p provider.MailProvider) ([]Report, int, error) {
	ok, err := folderExists(p)
	if err != nil || !ok {
		return nil, 0, err
	}
	ids, err := messageIDs(p)
	if err != nil {
		return nil, 0, err
	}

	var reports []Report
	var skipped int
	for _, id := range ids {
		_, header, body, err := p.GetMessagePartRaw(folder, id, nil, maxFetchSize)
		if err != nil {
			skipped++
			continue
		}
		found, bad := decodeMessage(append(header, body...))
		reports = append(reports, found...)
		skipped += bad
	}
	return reports, skipped, nil
}

func handleReports(ctx *alps.Context) error {
	var reports []Report
	var skipped int
	err := ctx.Session.DoMailWithContext(ctx.Request.Context(), func(p provider.MailProvider) error {
		var err error
		reports, skipped, err = collect(p)
		return err
	})
	if err != nil {
		return alps.NewHTTPError(http.StatusBadGateway, "could not read the DMARC folder")
	}
	return ctx.JSON(http.StatusOK, summarize(reports, skipped, time.Now()))
}

func init() {
	p := alps.GoPlugin{Name: "dmarc"}
	p.GET("/api/dmarc/reports", handleReports)
	alps.RegisterPluginLoader(p.Loader())
}
