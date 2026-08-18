import { LightningElement, api, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import { CloseActionScreenEvent } from "lightning/actions";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { subscribe, unsubscribe, onError } from "lightning/empApi";
import getOpportunityCases from "@salesforce/apex/OpportunityCasesController.getOpportunityCases";
import createCase from "@salesforce/apex/OpportunityCasesController.createCase";
import getCaseStatusBreakdown from "@salesforce/apex/OpportunityCasesController.getCaseStatusBreakdown";

const COUNTING_EVENT_CHANNEL = "/event/CountingPlatformEvent__e";

const FIELDS = ["Name", "StageName", "Amount", "CloseDate"];

const COLUMNS = [
  { label: "Case Number", fieldName: "CaseNumber" },
  { label: "Subject", fieldName: "Subject" },
  { label: "Status", fieldName: "Status" },
  { label: "Priority", fieldName: "Priority" }
];

// Fixed hue per known status so color always means the same thing (color follows the entity, not its rank).
const STATUS_COLORS = {
  New: "#2a78d6",
  Working: "#eb6834",
  Escalated: "#1baf7a",
  Closed: "#eda100"
};
const FALLBACK_COLORS = ["#e87ba4", "#008300"];
const OTHER_COLOR = "#898781";
const MAX_SLICES = 6;

const CX = 40;
const CY = 40;
const RADIUS = 34;

function polarToCartesian(cx, cy, r, angleDeg) {
  const angleRad = (angleDeg * Math.PI) / 180;
  return { x: cx + r * Math.cos(angleRad), y: cy + r * Math.sin(angleRad) };
}

function describeSlicePath(cx, cy, r, startAngle, endAngle) {
  if (endAngle - startAngle >= 359.999) {
    // A full circle can't be drawn as a single arc; split it into two halves.
    const mid = startAngle + 180;
    return [
      describeSlicePath(cx, cy, r, startAngle, mid),
      describeSlicePath(cx, cy, r, mid, endAngle)
    ].join(" ");
  }
  const start = polarToCartesian(cx, cy, r, startAngle);
  const end = polarToCartesian(cx, cy, r, endAngle);
  const largeArcFlag = endAngle - startAngle > 180 ? 1 : 0;
  return `M ${cx} ${cy} L ${start.x} ${start.y} A ${r} ${r} 0 ${largeArcFlag} 1 ${end.x} ${end.y} Z`;
}

export default class RecordDetailsView extends LightningElement {
  @api recordId;
  @api objectApiName;

  fields = FIELDS;
  columns = COLUMNS;
  view = "form"; // 'form' | 'loading' | 'result'
  createdCase;

  subscription;

  @wire(getOpportunityCases, { opportunityId: "$recordId" })
  casesResult;

  @wire(getCaseStatusBreakdown, { opportunityId: "$recordId" })
  statusResult;

  get cases() {
    return this.casesResult?.data ?? [];
  }

  get statusSlices() {
    const data = this.statusResult?.data ?? [];
    const total = data.reduce((sum, row) => sum + row.count, 0);
    if (total === 0) {
      return [];
    }

    const known = Object.keys(STATUS_COLORS);
    const sorted = [...data].sort((a, b) => {
      const aRank = known.indexOf(a.status);
      const bRank = known.indexOf(b.status);
      if (aRank !== -1 || bRank !== -1) {
        return (aRank === -1 ? known.length : aRank) - (bRank === -1 ? known.length : bRank);
      }
      return b.count - a.count;
    });

    const visible = sorted.slice(0, MAX_SLICES);
    const overflowCount = sorted
      .slice(MAX_SLICES)
      .reduce((sum, row) => sum + row.count, 0);

    let fallbackIndex = 0;
    const buckets = visible.map((row) => ({
      status: row.status,
      count: row.count,
      color: STATUS_COLORS[row.status] || FALLBACK_COLORS[fallbackIndex++] || OTHER_COLOR
    }));
    if (overflowCount > 0) {
      buckets.push({ status: "Other", count: overflowCount, color: OTHER_COLOR });
    }

    let cumulativeAngle = -90;
    return buckets.map((bucket) => {
      const fraction = bucket.count / total;
      const startAngle = cumulativeAngle;
      const endAngle = cumulativeAngle + fraction * 360;
      cumulativeAngle = endAngle;
      return {
        key: bucket.status,
        status: bucket.status,
        count: bucket.count,
        percent: Math.round(fraction * 100),
        color: bucket.color,
        pathStyle: `fill: ${bucket.color}`,
        swatchStyle: `background-color: ${bucket.color}`,
        path: describeSlicePath(CX, CY, RADIUS, startAngle, endAngle)
      };
    });
  }

  get isFormView() {
    return this.view === "form";
  }

  get isLoadingView() {
    return this.view === "loading";
  }

  get isResultView() {
    return this.view === "result";
  }

  connectedCallback() {
    onError((error) => {
      // eslint-disable-next-line no-console
      console.error("EMP API error", error);
    });

    subscribe(COUNTING_EVENT_CHANNEL, -1, () => {
      this.view = "result";
    }).then((response) => {
      this.subscription = response;
    });
  }

  disconnectedCallback() {
    if (this.subscription) {
      unsubscribe(this.subscription);
    }
  }

  handleClose() {
    this.dispatchEvent(new CloseActionScreenEvent());
  }

  async handleStart() {
    this.view = "loading";
    try {
      this.createdCase = await createCase({ opportunityId: this.recordId });
      await Promise.all([
        refreshApex(this.casesResult),
        refreshApex(this.statusResult)
      ]);
    } catch (error) {
      this.view = "form";
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error Creating Case",
          message: error?.body?.message ?? error.message,
          variant: "error"
        })
      );
    }
  }
}
