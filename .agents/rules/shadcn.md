# shadcn UI Design System & Component Guidelines

## Rule: base-vs-radix.md

# Base vs Radix

API differences between `base` and `radix`. Check the `base` field from `npx shadcn@latest info`.

## Contents

- Composition: asChild vs render
- Button / trigger as non-button element
- Select (items prop, placeholder, positioning, multiple, object values)
- ToggleGroup (type vs multiple)
- Slider (scalar vs array)
- Accordion (type and defaultValue)

---

## Composition: asChild (radix) vs render (base)

Radix uses `asChild` to replace the default element. Base uses `render`. Don't wrap triggers in extra elements.

**Incorrect:**

```tsx
<DialogTrigger>
  <div>
    <Button>Open</Button>
  </div>
</DialogTrigger>
```

**Correct (radix):**

```tsx
<DialogTrigger asChild>
  <Button>Open</Button>
</DialogTrigger>
```

**Correct (base):**

```tsx
<DialogTrigger render={<Button />}>Open</DialogTrigger>
```

This applies to all trigger and close components: `DialogTrigger`, `SheetTrigger`, `AlertDialogTrigger`, `DropdownMenuTrigger`, `PopoverTrigger`, `TooltipTrigger`, `CollapsibleTrigger`, `DialogClose`, `SheetClose`, `NavigationMenuLink`, `BreadcrumbLink`, `SidebarMenuButton`, `Badge`, `Item`.

---

## Button / trigger as non-button element (base only)

When `render` changes an element to a non-button (`<a>`, `<span>`), add `nativeButton={false}`.

**Incorrect (base):** missing `nativeButton={false}`.

```tsx
<Button render={<a href="/docs" />}>Read the docs</Button>
```

**Correct (base):**

```tsx
<Button render={<a href="/docs" />} nativeButton={false}>
  Read the docs
</Button>
```

**Correct (radix):**

```tsx
<Button asChild>
  <a href="/docs">Read the docs</a>
</Button>
```

Same for triggers whose `render` is not a `Button`:

```tsx
// base.
<PopoverTrigger render={<InputGroupAddon />} nativeButton={false}>
  Pick date
</PopoverTrigger>
```

---

## Select

**items prop (base only).** Base requires an `items` prop on the root. Radix uses inline JSX only.

**Incorrect (base):**

```tsx
<Select>
  <SelectTrigger><SelectValue placeholder="Select a fruit" /></SelectTrigger>
</Select>
```

**Correct (base):**

```tsx
const items = [
  { label: "Select a fruit", value: null },
  { label: "Apple", value: "apple" },
  { label: "Banana", value: "banana" },
]

<Select items={items}>
  <SelectTrigger>
    <SelectValue />
  </SelectTrigger>
  <SelectContent>
    <SelectGroup>
      {items.map((item) => (
        <SelectItem key={item.value} value={item.value}>{item.label}</SelectItem>
      ))}
    </SelectGroup>
  </SelectContent>
</Select>
```

**Correct (radix):**

```tsx
<Select>
  <SelectTrigger>
    <SelectValue placeholder="Select a fruit" />
  </SelectTrigger>
  <SelectContent>
    <SelectGroup>
      <SelectItem value="apple">Apple</SelectItem>
      <SelectItem value="banana">Banana</SelectItem>
    </SelectGroup>
  </SelectContent>
</Select>
```

**Placeholder.** Base uses a `{ value: null }` item in the items array. Radix uses `<SelectValue placeholder="...">`.

**Content positioning.** Base uses `alignItemWithTrigger`. Radix uses `position`.

```tsx
// base.
<SelectContent alignItemWithTrigger={false} side="bottom">

// radix.
<SelectContent position="popper">
```

---

## Select — multiple selection and object values (base only)

Base supports `multiple`, render-function children on `SelectValue`, and object values with `itemToStringValue`. Radix is single-select with string values only.

**Correct (base — multiple selection):**

```tsx
<Select items={items} multiple defaultValue={[]}>
  <SelectTrigger>
    <SelectValue>
      {(value: string[]) => value.length === 0 ? "Select fruits" : `${value.length} selected`}
    </SelectValue>
  </SelectTrigger>
  ...
</Select>
```

**Correct (base — object values):**

```tsx
<Select defaultValue={plans[0]} itemToStringValue={(plan) => plan.name}>
  <SelectTrigger>
    <SelectValue>{(value) => value.name}</SelectValue>
  </SelectTrigger>
  ...
</Select>
```

---

## ToggleGroup

Base uses a `multiple` boolean prop. Radix uses `type="single"` or `type="multiple"`.

**Incorrect (base):**

```tsx
<ToggleGroup type="single" defaultValue="daily">
  <ToggleGroupItem value="daily">Daily</ToggleGroupItem>
</ToggleGroup>
```

**Correct (base):**

```tsx
// Single (no prop needed), defaultValue is always an array.
<ToggleGroup defaultValue={["daily"]} spacing={2}>
  <ToggleGroupItem value="daily">Daily</ToggleGroupItem>
  <ToggleGroupItem value="weekly">Weekly</ToggleGroupItem>
</ToggleGroup>

// Multi-selection.
<ToggleGroup multiple>
  <ToggleGroupItem value="bold">Bold</ToggleGroupItem>
  <ToggleGroupItem value="italic">Italic</ToggleGroupItem>
</ToggleGroup>
```

**Correct (radix):**

```tsx
// Single, defaultValue is a string.
<ToggleGroup type="single" defaultValue="daily" spacing={2}>
  <ToggleGroupItem value="daily">Daily</ToggleGroupItem>
  <ToggleGroupItem value="weekly">Weekly</ToggleGroupItem>
</ToggleGroup>

// Multi-selection.
<ToggleGroup type="multiple">
  <ToggleGroupItem value="bold">Bold</ToggleGroupItem>
  <ToggleGroupItem value="italic">Italic</ToggleGroupItem>
</ToggleGroup>
```

**Controlled single value:**

```tsx
// base — wrap/unwrap arrays.
const [value, setValue] = React.useState("normal")
<ToggleGroup value={[value]} onValueChange={(v) => setValue(v[0])}>

// radix — plain string.
const [value, setValue] = React.useState("normal")
<ToggleGroup type="single" value={value} onValueChange={setValue}>
```

---

## Slider

Base accepts a plain number for a single thumb. Radix always requires an array.

**Incorrect (base):**

```tsx
<Slider defaultValue={[50]} max={100} step={1} />
```

**Correct (base):**

```tsx
<Slider defaultValue={50} max={100} step={1} />
```

**Correct (radix):**

```tsx
<Slider defaultValue={[50]} max={100} step={1} />
```

Both use arrays for range sliders. Controlled `onValueChange` in base may need a cast:

```tsx
// base.
const [value, setValue] = React.useState([0.3, 0.7])
<Slider value={value} onValueChange={(v) => setValue(v as number[])} />

// radix.
const [value, setValue] = React.useState([0.3, 0.7])
<Slider value={value} onValueChange={setValue} />
```

---

## Accordion

Radix requires `type="single"` or `type="multiple"` and supports `collapsible`. `defaultValue` is a string. Base uses no `type` prop, uses `multiple` boolean, and `defaultValue` is always an array.

**Incorrect (base):**

```tsx
<Accordion type="single" collapsible defaultValue="item-1">
  <AccordionItem value="item-1">...</AccordionItem>
</Accordion>
```

**Correct (base):**

```tsx
<Accordion defaultValue={["item-1"]}>
  <AccordionItem value="item-1">...</AccordionItem>
</Accordion>

// Multi-select.
<Accordion multiple defaultValue={["item-1", "item-2"]}>
  <AccordionItem value="item-1">...</AccordionItem>
  <AccordionItem value="item-2">...</AccordionItem>
</Accordion>
```

**Correct (radix):**

```tsx
<Accordion type="single" collapsible defaultValue="item-1">
  <AccordionItem value="item-1">...</AccordionItem>
</Accordion>
```


---

## Rule: chat.md

# Chat & Messaging

Components for conversation and chat UI. Compose these instead of hand-rolling
bubbles, scroll containers, dividers, or attachment cards.

Install: `npx shadcn@latest add message-scroller message bubble attachment marker`

The same component names and props ship for both `base` and `radix`; only
composition differs (`render` vs `asChild`). See [base-vs-radix.md](./base-vs-radix.md).

## Contents

- Scrollable threads use MessageScroller
- Message rows use Message
- Message surfaces use Bubble
- Attachments use Attachment
- System notes and dividers use Marker
- Streaming, anchoring, and jump-to-latest are built in
- Escape hatch: the scroller hooks

---

## Scrollable threads use MessageScroller

A conversation that scrolls, follows new messages, restores position, or jumps
to a message uses `MessageScroller`. Don't build a raw overflow container with
manual scroll wiring, and don't reach for `ScrollArea`.

The parts nest in a fixed order. Every direct child of the content is wrapped in
a `MessageScrollerItem` so the scroller can measure, anchor, preserve position,
track visibility, and jump to it. `MessageScrollerButton` sits inside
`MessageScroller`, after the viewport.

**Incorrect:**

```tsx
// Hand-rolled scroll container with manual stick-to-bottom logic.
<div ref={scrollRef} onScroll={handleScroll} className="flex-1 overflow-y-auto">
  <div className="flex flex-col gap-6 p-4">
    {messages.map((m) => (
      <ChatMessage key={m.id} message={m} />
    ))}
  </div>
</div>
```

**Correct:**

```tsx
<MessageScrollerProvider autoScroll>
  <MessageScroller>
    <MessageScrollerViewport>
      <MessageScrollerContent>
        {messages.map((message) => (
          <MessageScrollerItem
            key={message.id}
            messageId={message.id}
            scrollAnchor={message.role === "user"}
          >
            <Message align={message.role === "user" ? "end" : "start"}>
              {/* ...message content... */}
            </Message>
          </MessageScrollerItem>
        ))}
      </MessageScrollerContent>
    </MessageScrollerViewport>
    <MessageScrollerButton />
  </MessageScroller>
</MessageScrollerProvider>
```

---

## Message rows use Message

`Message` lays out a single row: avatar, header, content, footer, with
alignment. Group consecutive rows from one sender with `MessageGroup`. Don't
rebuild the row from flex divs.

`align="end"` is the current user's side; `align="start"` is everyone else.

```tsx
<Message align="start">
  <MessageAvatar>
    <Avatar>
      <AvatarImage src={sender.avatar} alt={sender.name} />
      <AvatarFallback>{initials}</AvatarFallback>
    </Avatar>
  </MessageAvatar>
  <MessageContent>
    <MessageHeader>{sender.name}</MessageHeader>
    <Bubble>
      <BubbleContent>{text}</BubbleContent>
    </Bubble>
    <MessageFooter>{time}</MessageFooter>
  </MessageContent>
</Message>
```

---

## Message surfaces use Bubble

The colored message surface is `Bubble` + `BubbleContent`, never a styled `div`
with `bg-muted` / `bg-primary` and hand-managed corners.

- `variant`: `default`, `secondary`, `muted`, `tinted`, `outline`, `ghost`, `destructive`.
- `align`: `start` or `end` (matches the `Message` side).

`BubbleReactions` renders the reaction cluster. `side` (`top` | `bottom`) and
`align` (`start` | `end`) position it against the bubble. Don't lay reactions out
with absolutely-positioned `Badge`s.

**Incorrect:**

```tsx
<div className="w-fit rounded-2xl bg-primary px-3 py-2 text-primary-foreground">
  {text}
</div>
```

**Correct:**

```tsx
<Bubble variant="default" align="end">
  <BubbleContent>{text}</BubbleContent>
  <BubbleReactions side="bottom" align="end">
    <Badge variant="secondary">👍 2</Badge>
  </BubbleReactions>
</Bubble>
```

---

## Attachments use Attachment

File and image attachments use `Attachment`, not `Item` or a custom card. It
carries upload state, so wire `state` to the real status rather than rendering a
separate spinner.

- `state`: `idle`, `uploading`, `processing`, `error`, `done`. `uploading` and
  `processing` apply the `shimmer` animation to the title automatically.
- `size`: `default`, `sm`, `xs`. `orientation`: `horizontal`, `vertical`.
- Use `AttachmentGroup` to lay out several attachments in a scrolling row.

```tsx
<Attachment state="done">
  <AttachmentMedia variant="icon">
    <FileTextIcon />
  </AttachmentMedia>
  <AttachmentContent>
    <AttachmentTitle>homepage-feedback.pdf</AttachmentTitle>
    <AttachmentDescription>PDF · 2.4 MB</AttachmentDescription>
  </AttachmentContent>
  <AttachmentActions>
    <AttachmentAction>
      <DownloadIcon />
    </AttachmentAction>
  </AttachmentActions>
</Attachment>
```

For an image, use `<AttachmentMedia variant="image">` with an `img` child.

---

## System notes and dividers use Marker

Status lines ("Sarah joined the conversation"), date dividers ("Today"), and
labeled separators are `Marker`, not a `Separator` plus a centered span.

- `variant`: `default` (plain row), `separator` (centered label with rules on
  each side), `border` (bottom-bordered row).
- `MarkerIcon` holds a leading icon; `MarkerContent` holds the label.

**Incorrect:**

```tsx
<div className="flex items-center gap-3 py-2">
  <Separator className="flex-1" />
  <span className="text-xs text-muted-foreground">Today</span>
  <Separator className="flex-1" />
</div>
```

**Correct:**

```tsx
<Marker variant="separator">
  <MarkerContent>Today</MarkerContent>
</Marker>
```

---

## Streaming, anchoring, and jump-to-latest are built in

`MessageScroller` handles the behavior that chat UIs usually reinvent. Don't
write a `useStickToBottom` hook, a `ResizeObserver`, or manual `scrollTop` math.

- **Follow the live edge while streaming.** `MessageScrollerProvider` with
  `autoScroll` keeps the view pinned to new content and yields the moment the
  user scrolls up. Streaming token updates that grow the last message are
  followed automatically.
- **Anchor a turn.** `scrollAnchor` on a `MessageScrollerItem` marks the row to
  hold in view (typically the user's message that started the turn).
- **Jump to latest.** `MessageScrollerButton` appears when the user scrolls away
  and scrolls back on click. `direction="end"` (default) or `direction="start"`.
  It is a self-managing control, so don't gate it behind your own scroll-position
  state.
- **Open a saved transcript without a flash.** `defaultScrollPosition` applies
  after mount. When it is `"end"` or `"last-anchor"`, the viewport has
  `data-pending-scroll` until that position is applied. The styled viewport
  hides. For `"end"` on first paint when messages are in the server HTML, copy
  this script into the page, not into the primitive. Skip it for `"last-anchor"`
  and for client-fetched messages. Keep `suppressHydrationWarning` on the
  viewport. Pass a `nonce` if you use a Content Security Policy.

```tsx
const scrollToEndScript = `(function () {
  var viewport = document.getElementById("messages")
  if (!viewport) {
    return
  }
  viewport.scrollTop = viewport.scrollHeight
  viewport.removeAttribute("data-pending-scroll")
})()`

<MessageScroller>
  <MessageScrollerViewport id="messages" suppressHydrationWarning>
    <MessageScrollerContent>{/* transcript */}</MessageScrollerContent>
  </MessageScrollerViewport>
  <script dangerouslySetInnerHTML={{ __html: scrollToEndScript }} />
  <MessageScrollerButton />
</MessageScroller>
```

For a "thinking…" indicator while the model generates, apply the `shimmer`
utility to text. Don't author a custom keyframe animation. See
[styling.md](./styling.md).

---

## Escape hatch: the scroller hooks

For behavior the parts don't expose, read state from the hooks rather than
re-implementing the scroller: `useMessageScroller`,
`useMessageScrollerVisibility`, and `useMessageScrollerScrollable`. They come
from the auto-installed `@shadcn/react` dependency, so there's nothing extra to
install. Reach for them only when composition can't express what you need.


---

## Rule: composition.md

# Component Composition

## Contents

- Items always inside their Group component
- Callouts use Alert
- Empty states use Empty component
- Toast notifications follow the project base
- Choosing between overlay components
- Dialog, Sheet, and Drawer always need a Title
- Card structure
- Button has no isPending or isLoading prop
- TabsTrigger must be inside TabsList
- Avatar always needs AvatarFallback
- Use Separator instead of raw hr or border divs
- Use Skeleton for loading placeholders
- Use Badge instead of custom styled spans

---

## Items always inside their Group component

Never render items directly inside the content container.

**Incorrect:**

```tsx
<SelectContent>
  <SelectItem value="apple">Apple</SelectItem>
  <SelectItem value="banana">Banana</SelectItem>
</SelectContent>
```

**Correct:**

```tsx
<SelectContent>
  <SelectGroup>
    <SelectItem value="apple">Apple</SelectItem>
    <SelectItem value="banana">Banana</SelectItem>
  </SelectGroup>
</SelectContent>
```

This applies to all group-based components:

| Item | Group |
|------|-------|
| `SelectItem`, `SelectLabel` | `SelectGroup` |
| `DropdownMenuItem`, `DropdownMenuLabel`, `DropdownMenuSub` | `DropdownMenuGroup` |
| `MenubarItem` | `MenubarGroup` |
| `ContextMenuItem` | `ContextMenuGroup` |
| `CommandItem` | `CommandGroup` |
| `MessageScrollerItem` | `MessageScrollerContent` |
| `Message` (consecutive, same sender) | `MessageGroup` |
| `Bubble` (stacked) | `BubbleGroup` |
| `Attachment` (in a row) | `AttachmentGroup` |

Chat components nest in a fixed order (`MessageScrollerProvider` → `MessageScroller` → `MessageScrollerViewport` → `MessageScrollerContent` → `MessageScrollerItem`). See [chat.md](./chat.md).

---

## Callouts use Alert

```tsx
<Alert>
  <AlertTitle>Warning</AlertTitle>
  <AlertDescription>Something needs attention.</AlertDescription>
</Alert>
```

---

## Empty states use Empty component

```tsx
<Empty>
  <EmptyHeader>
    <EmptyMedia variant="icon"><FolderIcon /></EmptyMedia>
    <EmptyTitle>No projects yet</EmptyTitle>
    <EmptyDescription>Get started by creating a new project.</EmptyDescription>
  </EmptyHeader>
  <EmptyContent>
    <Button>Create Project</Button>
  </EmptyContent>
</Empty>
```

---

## Toast notifications follow the project base

For Base UI projects, use the `toast` component:

```tsx
import { toast } from "@/components/ui/toast"

toast.add({
  title: "Changes saved.",
})
```

For Radix and React Aria projects, use Sonner:

```tsx
import { toast } from "sonner"

toast.success("Changes saved.")
toast.error("Something went wrong.")
toast("File deleted.", {
  action: { label: "Undo", onClick: () => undoDelete() },
})
```

---

## Choosing between overlay components

| Use case | Component |
|----------|-----------|
| Focused task that requires input | `Dialog` |
| Destructive action confirmation | `AlertDialog` |
| Side panel with details or filters | `Sheet` |
| Mobile-first bottom panel | `Drawer` |
| Quick info on hover | `HoverCard` |
| Small contextual content on click | `Popover` |

---

## Dialog, Sheet, and Drawer always need a Title

`DialogTitle`, `SheetTitle`, `DrawerTitle` are required for accessibility. Use `className="sr-only"` if visually hidden.

```tsx
<DialogContent>
  <DialogHeader>
    <DialogTitle>Edit Profile</DialogTitle>
    <DialogDescription>Update your profile.</DialogDescription>
  </DialogHeader>
  ...
</DialogContent>
```

---

## Card structure

Use full composition — don't dump everything into `CardContent`:

```tsx
<Card>
  <CardHeader>
    <CardTitle>Team Members</CardTitle>
    <CardDescription>Manage your team.</CardDescription>
  </CardHeader>
  <CardContent>...</CardContent>
  <CardFooter>
    <Button>Invite</Button>
  </CardFooter>
</Card>
```

---

## Button has no isPending or isLoading prop

Compose with `Spinner` + `data-icon` + `disabled`:

```tsx
<Button disabled>
  <Spinner data-icon="inline-start" />
  Saving...
</Button>
```

---

## TabsTrigger must be inside TabsList

Never render `TabsTrigger` directly inside `Tabs` — always wrap in `TabsList`:

```tsx
<Tabs defaultValue="account">
  <TabsList>
    <TabsTrigger value="account">Account</TabsTrigger>
    <TabsTrigger value="password">Password</TabsTrigger>
  </TabsList>
  <TabsContent value="account">...</TabsContent>
</Tabs>
```

---

## Avatar always needs AvatarFallback

Always include `AvatarFallback` for when the image fails to load:

```tsx
<Avatar>
  <AvatarImage src="/avatar.png" alt="User" />
  <AvatarFallback>JD</AvatarFallback>
</Avatar>
```

---

## Use existing components instead of custom markup

| Instead of | Use |
|---|---|
| `<hr>` or `<div className="border-t">` | `<Separator />` |
| `<div className="animate-pulse">` with styled divs | `<Skeleton className="h-4 w-3/4" />` |
| `<span className="rounded-full bg-green-100 ...">` | `<Badge variant="secondary">` |


---

## Rule: forms.md

# Forms & Inputs

## Contents

- Forms use FieldGroup + Field
- InputGroup requires InputGroupInput/InputGroupTextarea
- Buttons inside inputs use InputGroup + InputGroupAddon
- Option sets (2–7 choices) use ToggleGroup
- FieldSet + FieldLegend for grouping related fields
- Field validation and disabled states

---

## Forms use FieldGroup + Field

Always use `FieldGroup` + `Field` — never raw `div` with `space-y-*`:

```tsx
<FieldGroup>
  <Field>
    <FieldLabel htmlFor="email">Email</FieldLabel>
    <Input id="email" type="email" />
  </Field>
  <Field>
    <FieldLabel htmlFor="password">Password</FieldLabel>
    <Input id="password" type="password" />
  </Field>
</FieldGroup>
```

Use `Field orientation="horizontal"` for settings pages. Use `FieldLabel className="sr-only"` for visually hidden labels.

**Choosing form controls:**

- Simple text input → `Input`
- Dropdown with predefined options → `Select`
- Searchable dropdown → `Combobox`
- Native HTML select (no JS) → `native-select`
- Boolean toggle → `Switch` (for settings) or `Checkbox` (for forms)
- Single choice from few options → `RadioGroup`
- Toggle between 2–5 options → `ToggleGroup` + `ToggleGroupItem`
- OTP/verification code → `InputOTP`
- Multi-line text → `Textarea`

---

## InputGroup requires InputGroupInput/InputGroupTextarea

Never use raw `Input` or `Textarea` inside an `InputGroup`.

**Incorrect:**

```tsx
<InputGroup>
  <Input placeholder="Search..." />
</InputGroup>
```

**Correct:**

```tsx
import { InputGroup, InputGroupInput } from "@/components/ui/input-group"

<InputGroup>
  <InputGroupInput placeholder="Search..." />
</InputGroup>
```

---

## Buttons inside inputs use InputGroup + InputGroupAddon

Never place a `Button` directly inside or adjacent to an `Input` with custom positioning.

**Incorrect:**

```tsx
<div className="relative">
  <Input placeholder="Search..." className="pr-10" />
  <Button className="absolute right-0 top-0" size="icon">
    <SearchIcon />
  </Button>
</div>
```

**Correct:**

```tsx
import { InputGroup, InputGroupInput, InputGroupAddon } from "@/components/ui/input-group"

<InputGroup>
  <InputGroupInput placeholder="Search..." />
  <InputGroupAddon>
    <Button size="icon">
      <SearchIcon data-icon="inline-start" />
    </Button>
  </InputGroupAddon>
</InputGroup>
```

---

## Option sets (2–7 choices) use ToggleGroup

Don't manually loop `Button` components with active state.

**Incorrect:**

```tsx
const [selected, setSelected] = useState("daily")

<div className="flex gap-2">
  {["daily", "weekly", "monthly"].map((option) => (
    <Button
      key={option}
      variant={selected === option ? "default" : "outline"}
      onClick={() => setSelected(option)}
    >
      {option}
    </Button>
  ))}
</div>
```

**Correct:**

```tsx
import { ToggleGroup, ToggleGroupItem } from "@/components/ui/toggle-group"

<ToggleGroup spacing={2}>
  <ToggleGroupItem value="daily">Daily</ToggleGroupItem>
  <ToggleGroupItem value="weekly">Weekly</ToggleGroupItem>
  <ToggleGroupItem value="monthly">Monthly</ToggleGroupItem>
</ToggleGroup>
```

Combine with `Field` for labelled toggle groups:

```tsx
<Field orientation="horizontal">
  <FieldTitle id="theme-label">Theme</FieldTitle>
  <ToggleGroup aria-labelledby="theme-label" spacing={2}>
    <ToggleGroupItem value="light">Light</ToggleGroupItem>
    <ToggleGroupItem value="dark">Dark</ToggleGroupItem>
    <ToggleGroupItem value="system">System</ToggleGroupItem>
  </ToggleGroup>
</Field>
```

> **Note:** `defaultValue` and `type`/`multiple` props differ between base and radix. See [base-vs-radix.md](./base-vs-radix.md#togglegroup).

---

## FieldSet + FieldLegend for grouping related fields

Use `FieldSet` + `FieldLegend` for related checkboxes, radios, or switches — not `div` with a heading:

```tsx
<FieldSet>
  <FieldLegend variant="label">Preferences</FieldLegend>
  <FieldDescription>Select all that apply.</FieldDescription>
  <FieldGroup className="gap-3">
    <Field orientation="horizontal">
      <Checkbox id="dark" />
      <FieldLabel htmlFor="dark" className="font-normal">Dark mode</FieldLabel>
    </Field>
  </FieldGroup>
</FieldSet>
```

---

## Field validation and disabled states

Both attributes are needed — `data-invalid`/`data-disabled` styles the field (label, description), while `aria-invalid`/`disabled` styles the control.

```tsx
// Invalid.
<Field data-invalid>
  <FieldLabel htmlFor="email">Email</FieldLabel>
  <Input id="email" aria-invalid />
  <FieldDescription>Invalid email address.</FieldDescription>
</Field>

// Disabled.
<Field data-disabled>
  <FieldLabel htmlFor="email">Email</FieldLabel>
  <Input id="email" disabled />
</Field>
```

Works for all controls: `Input`, `Textarea`, `Select`, `Checkbox`, `RadioGroupItem`, `Switch`, `Slider`, `NativeSelect`, `InputOTP`.


---

## Rule: icons.md

# Icons

**Always use the project's configured `iconLibrary` for imports.** Check the `iconLibrary` field from project context: `lucide` → `lucide-react`, `tabler` → `@tabler/icons-react`, etc. Never assume `lucide-react`.

---

## Icons in Button use data-icon attribute

Add `data-icon="inline-start"` (prefix) or `data-icon="inline-end"` (suffix) to the icon. No sizing classes on the icon.

**Incorrect:**

```tsx
<Button>
  <SearchIcon className="mr-2 size-4" />
  Search
</Button>
```

**Correct:**

```tsx
<Button>
  <SearchIcon data-icon="inline-start"/>
  Search
</Button>

<Button>
  Next
  <ArrowRightIcon data-icon="inline-end"/>
</Button>
```

---

## No sizing classes on icons inside components

Components handle icon sizing via CSS. Don't add `size-4`, `w-4 h-4`, or other sizing classes to icons inside `Button`, `DropdownMenuItem`, `Alert`, `Sidebar*`, or other shadcn components. Unless the user explicitly asks for custom icon sizes.

**Incorrect:**

```tsx
<Button>
  <SearchIcon className="size-4" data-icon="inline-start" />
  Search
</Button>

<DropdownMenuItem>
  <SettingsIcon className="mr-2 size-4" />
  Settings
</DropdownMenuItem>
```

**Correct:**

```tsx
<Button>
  <SearchIcon data-icon="inline-start" />
  Search
</Button>

<DropdownMenuItem>
  <SettingsIcon />
  Settings
</DropdownMenuItem>
```

---

## Pass icons as component objects, not string keys

Use `icon={CheckIcon}`, not a string key to a lookup map.

**Incorrect:**

```tsx
const iconMap = {
  check: CheckIcon,
  alert: AlertIcon,
}

function StatusBadge({ icon }: { icon: string }) {
  const Icon = iconMap[icon]
  return <Icon />
}

<StatusBadge icon="check" />
```

**Correct:**

```tsx
// Import from the project's configured iconLibrary (e.g. lucide-react, @tabler/icons-react).
import { CheckIcon } from "lucide-react"

function StatusBadge({ icon: Icon }: { icon: React.ComponentType }) {
  return <Icon />
}

<StatusBadge icon={CheckIcon} />
```


---

## Rule: styling.md

# Styling & Customization

See [customization.md](../customization.md) for theming, CSS variables, and adding custom colors.

## Contents

- Semantic colors
- Built-in variants first
- className for layout only
- No space-x-* / space-y-*
- Prefer size-* over w-* h-* when equal
- Prefer truncate shorthand
- No manual dark: color overrides
- Use cn() for conditional classes
- No manual z-index on overlay components
- Use shimmer / scroll-fade utilities, not custom animations

---

## Semantic colors

**Incorrect:**

```tsx
<div className="bg-blue-500 text-white">
  <p className="text-gray-600">Secondary text</p>
</div>
```

**Correct:**

```tsx
<div className="bg-primary text-primary-foreground">
  <p className="text-muted-foreground">Secondary text</p>
</div>
```

---

## No raw color values for status/state indicators

For positive, negative, or status indicators, use Badge variants, semantic tokens like `text-destructive`, or define custom CSS variables — don't reach for raw Tailwind colors.

**Incorrect:**

```tsx
<span className="text-emerald-600">+20.1%</span>
<span className="text-green-500">Active</span>
<span className="text-red-600">-3.2%</span>
```

**Correct:**

```tsx
<Badge variant="secondary">+20.1%</Badge>
<Badge>Active</Badge>
<span className="text-destructive">-3.2%</span>
```

If you need a success/positive color that doesn't exist as a semantic token, use a Badge variant or ask the user about adding a custom CSS variable to the theme (see [customization.md](../customization.md)).

---

## Built-in variants first

**Incorrect:**

```tsx
<Button className="border border-input bg-transparent hover:bg-accent">
  Click me
</Button>
```

**Correct:**

```tsx
<Button variant="outline">Click me</Button>
```

---

## className for layout only

Use `className` for layout (e.g. `max-w-md`, `mx-auto`, `mt-4`), **not** for overriding component colors or typography. To change colors, use semantic tokens, built-in variants, or CSS variables.

**Incorrect:**

```tsx
<Card className="bg-blue-100 text-blue-900 font-bold">
  <CardContent>Dashboard</CardContent>
</Card>
```

**Correct:**

```tsx
<Card className="max-w-md mx-auto">
  <CardContent>Dashboard</CardContent>
</Card>
```

To customize a component's appearance, prefer these approaches in order:
1. **Built-in variants** — `variant="outline"`, `variant="destructive"`, etc.
2. **Semantic color tokens** — `bg-primary`, `text-muted-foreground`.
3. **CSS variables** — define custom colors in the global CSS file (see [customization.md](../customization.md)).

---

## No space-x-* / space-y-*

Use `gap-*` instead. `space-y-4` → `flex flex-col gap-4`. `space-x-2` → `flex gap-2`.

```tsx
<div className="flex flex-col gap-4">
  <Input />
  <Input />
  <Button>Submit</Button>
</div>
```

---

## Prefer size-* over w-* h-* when equal

`size-10` not `w-10 h-10`. Applies to icons, avatars, skeletons, etc.

---

## Prefer truncate shorthand

`truncate` not `overflow-hidden text-ellipsis whitespace-nowrap`.

---

## No manual dark: color overrides

Use semantic tokens — they handle light/dark via CSS variables. `bg-background text-foreground` not `bg-white dark:bg-gray-950`.

---

## Use cn() for conditional classes

Use the `cn()` utility from the project for conditional or merged class names. Don't write manual ternaries in className strings.

**Incorrect:**

```tsx
<div className={`flex items-center ${isActive ? "bg-primary text-primary-foreground" : "bg-muted"}`}>
```

**Correct:**

```tsx
import { cn } from "cn"

<div className={cn("flex items-center", isActive ? "bg-primary text-primary-foreground" : "bg-muted")}>
```

---

## No manual z-index on overlay components

`Dialog`, `Sheet`, `Drawer`, `AlertDialog`, `DropdownMenu`, `Popover`, `Tooltip`, `HoverCard` handle their own stacking. Never add `z-50` or `z-[999]`.

---

## Use shimmer / scroll-fade utilities, not custom animations

For a live "thinking…" or loading-text shimmer, apply the `shimmer` utility. Don't author a custom `@keyframes` or a `bg-clip-text` gradient sweep.

For scroll-aware edge fading on a scroll container, use `scroll-fade` (and the axis variants `scroll-fade-x` / `scroll-fade-b`). Don't hand-roll mask gradients. The chat components already apply these internally: `Attachment` shimmers its title during upload, and `MessageScrollerViewport` fades its edges.

**Incorrect:**

```tsx
<span className="animate-pulse bg-gradient-to-r from-muted-foreground/40 via-foreground/70 to-muted-foreground/40 bg-clip-text text-transparent [animation:shimmer_1.6s_infinite]">
  Thinking…
</span>
```

**Correct:**

```tsx
<span className="shimmer">Thinking…</span>
```


---

